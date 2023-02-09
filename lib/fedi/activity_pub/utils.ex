defmodule Fedi.ActivityPub.Utils do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Error
  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T
  alias Fedi.ActivityPub.ActorFacade

  @content_type_header "content-type"
  @accept_header "accept"
  @content_type_value "application/ld+json; profile=\"https:www.w3.org/ns/activitystreams\""
  @public_activity_streams "https://www.w3.org/ns/activitystreams#Public"
  @public_activity_streams_iri Utils.to_uri(@public_activity_streams)
  @public_json_ld "Public"
  @public_json_ld_as "as:Public"
  @public_addresses [@public_activity_streams, @public_json_ld, @public_json_ld_as]
  @reserved_collection_names ["inbox", "outbox", "following", "followers", "likes", "shares"]

  @doc """
  activity_streams_media_types contains all of the accepted ActivityStreams media
  types. Generated at init time.
  """
  def activity_streams_media_types do
    types = [
      "application/activity+json"
    ]

    semis = [";", " ;", " ; ", "; "]

    profiles = [
      "profile=https:www.w3.org/ns/activitystreams",
      "profile=\"https:www.w3.org/ns/activitystreams\""
    ]

    Enum.reduce(semis, types, fn semi, acc ->
      Enum.reduce(profiles, acc, fn profile, acc2 ->
        ["application/ld+json#{semi}#{profile}" | acc2]
      end)
    end)
    |> Enum.reverse()
  end

  @doc """
  Ref: [AP Section 3.2](https://www.w3.org/TR/activitypub/#retrieving-objects)
  The client MUST specify an Accept header with the application/ld+json;
  profile="https://www.w3.org/ns/activitystreams" media type in order to
  retrieve the activity.
  """
  def is_activity_pub_media_type(%Plug.Conn{} = conn, which_header) do
    Plug.Conn.get_req_header(conn, which_header)
    |> header_is_activity_pub_media_type()
  end

  @doc """
  header_is_activity_pub_media_type returns true if the header string contains one
  of the accepted ActivityStreams media types.

  Note we don't try to build a comprehensive parser and instead accept a
  tolerable amount of whitespace since the HTTP specification is ambiguous
  about the format and significance of whitespace.
  """
  def header_is_activity_pub_media_type([]), do: false

  def header_is_activity_pub_media_type([header | _]) do
    header_is_activity_pub_media_type(header)
  end

  def header_is_activity_pub_media_type(header) when is_binary(header) do
    found =
      Enum.find(activity_streams_media_types(), fn media_type ->
        String.contains?(header, media_type)
      end)

    !is_nil(found)
  end

  @doc """
  Returns true if the request is a POST request that has the
  ActivityStreams "content-type" header
  """
  def is_activity_pub_post(%Plug.Conn{} = conn) do
    conn.method == "POST" && is_activity_pub_media_type(conn, @content_type_header)
  end

  @doc """
  Returns true if the request is a GET request that has the
  ActivityStreams "accept" header
  """
  def is_activity_pub_get(%Plug.Conn{} = conn) do
    conn.method == "GET" && is_activity_pub_media_type(conn, @accept_header)
  end

  def decode_json_body(%Plug.Conn{} = conn) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, length: 25_000_000),
         {:ok, json} <- Jason.decode(body) do
      {:ok, conn, json}
    else
      {:error, _reason} ->
        Logger.error("Invalid json body")
        {:error, "Invalid json body"}
    end
  end

  @doc """
  Returns the IRI that indicates an Activity is meant
  to be visible for general public consumption.
  """
  def public_activity_streams, do: @public_activity_streams

  def public_addresses, do: @public_addresses

  @doc """
  Determines if an IRI string is the Public collection as defined in
  the spec, including JSON-LD compliant collections.

  Ref: [AP Section 5.6](https://www.w3.org/TR/activitypub/#public-addressing)
  """
  def public?(%URI{} = iri) do
    public?(URI.to_string(iri))
  end

  def public?(recipients) when is_map(recipients) do
    Map.keys(recipients) |> public?()
  end

  def public?([_ | _] = recipients) do
    Enum.any?(recipients, &public?(&1))
  end

  def public?(addr) when is_binary(addr) do
    Enum.member?(@public_addresses, addr)
  end

  def public?(_), do: false

  @doc """
  Returns a property's id, or raises an error if it is not found.
  """
  def to_id!(prop_or_type) when is_struct(prop_or_type) do
    case to_id(prop_or_type) do
      %URI{} = id -> id
      _ -> raise "No id or IRI set on property #{Utils.alias_module(prop_or_type.__struct__)}"
    end
  end

  @doc """
  Returns all the ids, for an iterating property.
  """
  def get_ids(%{values: values} = iter_prop) do
    Enum.reduce_while(values, [], fn prop, acc ->
      case to_id(prop) do
        %URI{} = id ->
          {:cont, [id | acc]}

        _ ->
          Logger.error("get_ids failed on #{inspect(iter_prop)}")
          {:halt, {:error, "No id or IRI was set"}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      ids -> {:ok, Enum.reverse(ids)}
    end
  end

  @doc """
  Returns a property's id, or nil it is not found.
  """
  def to_id(prop_or_type) when is_struct(prop_or_type) do
    case get_id(prop_or_type) do
      %URI{} = id ->
        id

      _ ->
        Utils.get_iri(prop_or_type)
    end
  end

  @doc """
  Returns a property's IRI or the 'id' property of its type, or nil if
  neither is set.
  """
  def get_iri_or_id(prop_or_type) when is_struct(prop_or_type) do
    case Utils.get_iri(prop_or_type) do
      %URI{} = id ->
        id

      _ ->
        Utils.get_json_ld_id(prop_or_type)
    end
  end

  @doc """
  Attempts to find the 'href' property, if the property is
  a Link or derived from a Link type.

  Returns nil if either the 'href' is not valid on this type,
  or it is not set.
  """
  # For iterating property
  def get_href(%{values: [prop | _]}) do
    get_href(prop)
  end

  # For functional property
  def get_href(%{member: member}) when is_struct(member) do
    get_href(member)
  end

  # For type
  def get_href(%{properties: properties} = as_value) when is_map(properties) do
    with true <- Utils.has_href?(as_value),
         %P.Href{xsd_any_uri_member: %URI{} = href} <-
           Map.get(properties, "href") do
      href
    else
      _ ->
        nil
    end
  end

  @doc """
  Attempts to find the 'id' property or, if it happens to be a
  Link or derived from Link type, the 'href' property instead.

  Raises an error if the id is not set and either the 'href' property is not
  valid on this type, or it is also not set.
  """
  def get_id!(prop_or_type) when is_struct(prop_or_type) do
    case get_id(prop_or_type) do
      %URI{} = id -> id
      _ -> raise "No id or href set on #{Utils.alias_module(prop_or_type.__struct__)}"
    end
  end

  @doc """
  Attempts to find the 'id' property or, if it happens to be a
  Link or derived from Link type, the 'href' property instead.

  Returns nil if the id is not set and either the 'href' property is not
  valid on this type, or it is also not set.
  """
  def get_id(prop_or_type) when is_struct(prop_or_type) do
    case Utils.get_json_ld_id(prop_or_type) do
      %URI{} = id ->
        id

      nil ->
        if Utils.has_href?(prop_or_type) do
          get_href(prop_or_type)
        else
          nil
        end
    end
  end

  @doc """
  Obtains the 'inReplyTo', 'object', 'target', and 'tag' values on an
  ActivityStreams value.

  Ref: [AP Section 7.1.2](https://w3.org/TR/activitypub/#inbox-forwarding)
  Ref: The values of inReplyTo, object, 'target' and/or 'tag' are objects owned by the server.
  """
  def get_inbox_forwarding_values(%{properties: properties} = _as_type) do
    ["object", "target", "inReplyTo", "tag"]
    |> Enum.reduce({[], []}, fn prop_name, {type_acc, iri_acc} = acc ->
      case Map.get(properties, prop_name) do
        %{values: values} when is_list(values) ->
          {types, iris} =
            Enum.reduce(values, {[], []}, fn
              %{member: member}, {type_acc2, iri_acc2} when is_struct(member) ->
                # Recurse into object and target
                {member_types, member_iris} = get_inbox_forwarding_values(member)
                {type_acc2 ++ [member | member_types], iri_acc2 ++ member_iris}

              %{iri: %URI{} = iri}, {type_acc2, iri_acc2} ->
                {type_acc2, [iri | iri_acc2]}

              _, acc2 ->
                acc2
            end)

          {type_acc ++ types, iri_acc ++ iris}

        %{member: member} when is_struct(member) ->
          # Recurse into object and target
          {member_types, member_iris} = get_inbox_forwarding_values(member)
          {type_acc ++ [member | member_types], iri_acc ++ member_iris}

        %{iri: %URI{} = iri} ->
          {type_acc, [iri | iri_acc]}

        _ ->
          acc
      end
    end)
  end

  @doc """
  Wraps the provided object in a Create activity.
  This will copy over the to, bto, cc, bcc, and audience
  properties. It will also copy over the published time if present.

  Ref: [AP Section 6.2.1](https://www.w3.org/TR/activitypub/#object-without-create)
  The server MUST accept a valid [ActivityStreams] object that isn't a
  subtype of Activity in the POST request to the outbox. The server then
  MUST attach this object as the object of a Create Activity. For
  non-transient objects, the server MUST attach an id to both the
  wrapping Create and its wrapped Object.

  Any to, bto, cc, bcc, and audience properties specified on the object
  MUST be copied over to the new Create activity by the server.
  """
  def wrap_in_create(%{properties: object_props, unknown: unknown} = object, %URI{} = actor_iri)
      when is_map(object_props) do
    type_prop = Fedi.JSONLD.Property.Type.new_type("Create")

    # Hoist @context into Create Activity
    {as_context, unknown} = Map.pop(unknown, "@context")
    object = struct(object, unknown: unknown)
    object_prop = %P.Object{alias: "", values: [%P.ObjectIterator{alias: "", member: object}]}

    actor_prop = %P.Actor{alias: "", values: [%P.ActorIterator{alias: "", iri: actor_iri}]}

    create_props = %{
      "type" => type_prop,
      "object" => object_prop,
      "actor" => actor_prop
    }

    # Copy properties from object to activity
    create_props =
      ["published", "to", "bto", "cc", "bcc", "audience"]
      |> Enum.reduce(create_props, fn prop_name, acc ->
        copy_property(acc, object_props, prop_name)
      end)

    T.Create.new(properties: create_props, context: as_context || :simple)
  end

  def copy_property(dest, source, prop_name) do
    case {prop_name, Map.get(source, prop_name)} do
      {"published", %P.Published{xsd_date_time_member: %DateTime{}} = published_prop} ->
        Map.put(dest, prop_name, published_prop)

      {prop_name, %{values: [_ | _]} = iter_prop} ->
        if Enum.member?(["to", "bto", "cc", "bcc", "audience"], prop_name) do
          Map.put(dest, prop_name, iter_prop)
        else
          dest
        end

      _ ->
        dest
    end
  end

  @doc """
  deduplicates the 'orderedItems' within an ordered
  collection type. Deduplication happens by the 'id' property.
  """
  def dedupe_ordered_items(ordered_collection) do
    case Utils.get_ordered_items(ordered_collection) do
      %{values: oi_iterator_props} = ordered_items when is_list(oi_iterator_props) ->
        {deduped, dropped, _seen} =
          oi_iterator_props
          |> Enum.with_index()
          |> Enum.reduce_while({[], 0, MapSet.new()}, fn {prop, idx}, {acc, dropped, seen} ->
            case to_id(prop) do
              %URI{} = id ->
                id = URI.to_string(id)

                if MapSet.member?(seen, id) do
                  {:cont, {acc, dropped + 1, seen}}
                else
                  {:cont, {[prop | acc], dropped, MapSet.put(seen, id)}}
                end

              _ ->
                {:halt,
                 {:error,
                  "Element #{idx + 1} in OrderedCollection does not have an ID nor is an IRI"}}
            end
          end)

        if dropped == 0 do
          {:ok, ordered_collection}
        else
          ordered_items = struct(ordered_items, values: Enum.reverse(deduped))
          {:ok, Utils.set_ordered_items(ordered_collection, ordered_items)}
        end

      _ ->
        {:ok, ordered_collection}
    end
  end

  def date_header_value(dt \\ nil) do
    dt = dt || NaiveDateTime.utc_now()
    Timex.format!(dt, "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT")
  end

  @doc """
  Sets headers needed in the HTTP response, such but not
  limited to the Content-Type, Date, and Digest headers.
  """
  def add_response_headers(%Plug.Conn{} = conn, body) do
    digest = "SHA-256=" <> (:crypto.hash(:sha256, body) |> Base.encode64())

    [
      # RFC 7231 §7.1.1.2
      {"date", date_header_value()},
      # RFC 3230 and RFC 5843
      {"digest", digest}
    ]
    |> Enum.reduce(conn, fn {key, value}, acc ->
      Plug.Conn.put_resp_header(acc, key, value)
    end)
    |> Plug.Conn.put_resp_content_type(@content_type_value)
  end

  def send_json_resp(conn, status_or_error, body \\ nil, opts \\ [])

  def send_json_resp(%Plug.Conn{} = conn, status, nil, opts) when is_atom(status) do
    send_json_resp(
      conn,
      status,
      message_for_status(status),
      opts
    )
  end

  def send_json_resp(
        %Plug.Conn{} = conn,
        %Error{status: :unprocessable_entity, message: message},
        nil,
        opts
      ) do
    send_json_resp(
      conn,
      :unprocessable_entity,
      "Validation error: #{message}",
      opts
    )
  end

  def send_json_resp(%Plug.Conn{} = conn, %Error{status: status}, nil, opts) do
    send_json_resp(
      conn,
      status,
      message_for_status(status),
      opts
    )
  end

  def send_json_resp(%Plug.Conn{} = conn, status, body, opts) when is_binary(body) do
    content_type =
      if Plug.Conn.Status.code(status) > 299 do
        "application/json"
      else
        Plug.Conn.get_req_header(conn, "accept") |> get_best_content_type()
      end

    conn =
      case Keyword.get(opts, :actor_state) do
        nil -> conn
        actor_state -> Plug.Conn.put_private(conn, :actor_state, actor_state)
      end

    conn
    |> Plug.Conn.put_resp_content_type(content_type)
    |> Plug.Conn.send_resp(status, body)
  end

  def message_for_status(:ok), do: "OK"

  def message_for_status(:unprocessable_entity), do: "Validation error"

  def message_for_status(status) when is_atom(status) do
    Atom.to_string(status) |> String.replace("_", " ") |> Fedi.Streams.Utils.capitalize()
  end

  @content_types [
    {"application/ld+json",
     "application/ld+json; profile=\"https:www.w3.org/ns/activitystreams\""},
    {"application/activity+json", "application/activity+json"}
  ]

  def get_best_content_type(accepts) do
    found =
      Enum.find(@content_types, fn {accept, _value} ->
        Enum.find(accepts, &String.starts_with?(&1, accept))
      end)

    case found do
      {_accept, value} -> value
      _ -> "application/json"
    end
  end

  def is_or_extends?(%{__struct__: module}, type_name) when is_binary(type_name) do
    apply(module, :is_or_extends?, [type_name])
  end

  def is_or_extends?(as_value, type_names) when is_struct(as_value) and is_list(type_names) do
    Enum.any?(type_names, &is_or_extends?(as_value, &1))
  end

  @doc """
  Verifies that a value is an Activity with a valid id.
  """
  def validate_activity(as_value) when is_struct(as_value) do
    if is_or_extends?(as_value, "Activity") do
      case Utils.get_json_ld_id(as_value) do
        %URI{} = id ->
          {:ok, as_value, id}

        _ ->
          {:error, Utils.err_id_required(value: as_value)}
      end
    else
      type_name = Utils.alias_module(as_value.__struct__)
      {:error, Utils.err_type_not_an_activity(type_name, activity: as_value)}
    end
  end

  def validate_activity(as_value) do
    {:error, "#{inspect(as_value)} is not a struct"}
  end

  # On the top-level iterating property, e.g. %P.Object{}
  def make_id_map(%{values: values}, prop_name) do
    Enum.reduce_while(values, %{}, fn %{member: member}, acc ->
      with {:ok, value_map} <- make_id_map(member, prop_name) do
        {:cont, Map.merge(acc, value_map)}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      m -> {:ok, m}
    end
  end

  # On a value, e.g. %T.Note{}
  def make_id_map(%{properties: properties}, prop_name) do
    Map.get(properties, prop_name) |> make_id_map()
  end

  # On the selected iterating property, e.g. %P.To{}
  def make_id_map(%{values: values} = prop) when is_list(values) do
    with {:ok, ids} <- get_ids(prop) do
      id_map =
        Enum.map(ids, fn id -> {URI.to_string(id), id} end)
        |> Map.new()

      {:ok, id_map}
    end
  end

  def make_id_map(nil), do: {:ok, %{}}

  def make_id_map(other) do
    raise "make_id_map not implmented on #{inspect(other)}"
    {:error, "make_id_map not implmented on #{inspect(other)}"}
  end

  def property_and_id_map(%{properties: properties}, prop_name) do
    case Map.get(properties, prop_name) do
      %{__struct__: module, values: iters} = prop ->
        case make_id_map(prop) do
          {:ok, m} -> {prop, iters, module, m}
          _ -> {prop, iters, module, %{}}
        end

      _ ->
        {nil, [], Utils.property_module(prop_name), %{}}
    end
  end

  def property_and_id_map(_), do: {nil, [], nil, %{}}

  @doc """
  Creates a Tombstone object for the given ActivityStreams value.
  """
  def to_tombstone(
        %{alias: alias_, properties: former_properties} = as_type,
        %URI{} = id,
        now \\ nil
      ) do
    # id property
    id_prop = Fedi.JSONLD.Property.Id.new_id(id)

    # formerType property
    type_name = Fedi.Streams.BaseType.get_type_name(as_type)

    former_type = %P.FormerType{
      alias: alias_,
      values: [
        %P.FormerTypeIterator{
          alias: alias_,
          xsd_string_member: type_name
        }
      ]
    }

    # Copy over the published property if it existed
    published = Map.get(former_properties, "published")

    # Copy over the updated property if it existed
    updated = Map.get(former_properties, "updated")

    # Set deleted time to now.
    now = now || DateTime.utc_now()
    deleted = %P.Deleted{alias: alias_, xsd_date_time_member: now}

    properties =
      [
        {"id", id_prop},
        {"formerType", former_type},
        {"published", published},
        {"updated", updated},
        {"deleted", deleted}
      ]
      |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
      |> Map.new()

    %T.Tombstone{alias: alias_, properties: properties}
  end

  @doc """
  Returns the object property if the Host in the activity id
  IRI matches all of the Hosts in the object id IRIs.
  """
  def objects_match_activity_origin?(activity) do
    with {:activity_id, %URI{host: origin_host}} <- {:activity_id, get_id(activity)},
         {:activity_object, %P.Object{values: [_ | _] = object_iters} = object_prop} <-
           {:activity_object, Utils.get_object(activity)} do
      Enum.reduce_while(object_iters, {:ok, object_prop}, fn prop, acc ->
        case to_id(prop) do
          %URI{host: host} = object_id ->
            if host == origin_host do
              {:cont, acc}
            else
              {:halt, {:error, "Object #{object_id} is not in activity origin"}}
            end

          _ ->
            {:halt, {:error, Utils.err_id_required(activity: activity, property: "Object")}}
        end
      end)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> {:error, Utils.err_object_required(activity: activity)}
      {:activity_id, _} -> {:error, Utils.err_id_required(activity: activity)}
    end
  end

  @doc """
  Returns :ok if the actors on types in the 'object' property are all
  listed in the 'actor' property.

  Ref. 6.10. The Undo activity is used to undo a previous activity.
  See the Activity Vocabulary documentation on Inverse Activities and "Undo".
  For example, Undo may be used to undo a previous Like, Follow, or Block.

  The undo activity and the activity being undone MUST both have the same actor.
  Side effects should be undone, to the extent possible.

  For example, if undoing a Like, any counter that had been incremented previously
  should be decremented appropriately.
  """
  def object_actors_match_activity_actors?(
        %{box_iri: %URI{}} = context,
        activity
      ) do
    with {:activity_actors, [_ | _] = activity_actor_ids} <-
           {:activity_actors, Utils.get_iris(activity, "actor")},
         activity_actor_ids <-
           MapSet.new(activity_actor_ids),
         {:activity_object, %P.Object{values: [_ | _] = object_iters}} <-
           {:activity_object, Utils.get_object(activity)} do
      Enum.reduce_while(object_iters, [], fn prop, acc ->
        case get_object_actor_ids(context, prop) do
          {:error, reason} ->
            {:halt, {:error, reason}}

          ids when is_list(ids) ->
            {:cont, acc ++ ids}
        end
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        [_ | _] = object_actor_ids ->
          object_actor_ids = MapSet.new(object_actor_ids)

          if MapSet.subset?(activity_actor_ids, object_actor_ids) do
            :ok
          else
            {:error,
             %Error{
               code: :unmatched_object_actors,
               status: :unprocessable_entity,
               message: "Activity does not have all actors from its object's actors"
             }}
          end

        _ ->
          {:error, Utils.err_actor_required(activity: activity, property: "Object")}
      end
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_actors, _} ->
        {:error, Utils.err_actor_required(activity: activity)}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: activity)}
    end
  end

  def get_object_actor_ids(_context, %{member: object_type}) when is_struct(object_type) do
    Utils.get_iris(object_type, "actor")
  end

  def get_object_actor_ids(context, %{iri: %URI{} = object_iri}) do
    with {:ok, m} <- ActorFacade.db_dereference(context, object_iri),
         {:ok, as_type} <- Fedi.Streams.JSONResolver.resolve_with_as_context(m) do
      Utils.get_iris(as_type, "actor")
    end
  end

  def validate_accept_or_reject(%{box_iri: inbox_iri} = context, activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, actor_iri} <-
           ActorFacade.db_actor_for_inbox(context, inbox_iri),
         # Determine if we are in a follow on the 'object' property.
         # TODO Handle Accept multiple Follow
         {:ok, _follow, follow_id} <-
           find_follow(context, values, actor_iri),
         # Verify our Follow request exists and the peer didn't
         # fabricate it.
         {:activity_actor, %P.Actor{values: [_ | _]} = actor_prop} <-
           {:activity_actor, Utils.get_actor(activity)},
         # This may be a duplicate check if we dereferenced the
         # Follow above.
         {:ok, follow} <-
           ActorFacade.db_get(context, follow_id),
         # Ensure that we are one of the actors on the Follow.
         {:ok, %URI{}} <-
           follow_is_me?(follow, actor_iri),
         # Build map of original Accept or Reject actors
         {:ok, actors} <-
           get_ids(actor_prop),
         # Verify all actor(s) were on the original Follow.
         {:follow_object, %{values: [_ | _]} = follow_prop} <-
           {:follow_object, Utils.get_object(follow)},
         {:ok, follow_actors} <-
           get_ids(follow_prop),
         {:all_on_original, true} <-
           {:all_on_original, MapSet.subset?(MapSet.new(actors), MapSet.new(follow_actors))} do
      {:ok, actor_iri, actors}
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: activity)}

      {:activity_actor, _} ->
        {:error, Utils.err_actor_required(activity: activity)}

      {:follow_object, _} ->
        {:error, "No object in original Follow activity"}

      {:all_on_original, _} ->
        activity_name =
          case activity do
            %T.Accept{} ->
              "an Accept"

            _ ->
              "a Reject"
          end

        {:error,
         "Peer sent #{activity_name}/Follow, but was not an object in the original Follow"}
    end
  end

  def find_follow(
        %{box_iri: %URI{}} = context,
        values,
        %URI{} = actor_iri
      ) do
    Enum.reduce_while(values, {:error, "Not found"}, fn
      # Attempt to dereference the IRI instead
      %{iri: %URI{} = iri}, acc ->
        with {:ok, m} <- ActorFacade.db_dereference(context, iri),
             {:ok, as_type} <- Fedi.Streams.JSONResolver.resolve_with_as_context(m) do
          case follow_is_me?(as_type, actor_iri) do
            {:error, reason} -> {:halt, {:error, reason}}
            {:ok, %URI{} = follow_id} -> {:halt, {:ok, as_type, follow_id}}
            _ -> {:cont, acc}
          end
        else
          _ ->
            {:halt, {:error, "Unable to dereference a valid follow activity"}}
        end

      %{member: as_type}, acc when is_struct(as_type) ->
        case follow_is_me?(as_type, actor_iri) do
          {:error, reason} -> {:halt, {:error, reason}}
          {:ok, %URI{} = follow_id} -> {:halt, {:ok, as_type, follow_id}}
          _ -> {:cont, acc}
        end

      _, _ ->
        {:halt, {:error, "Invalid follow activity"}}
    end)
  end

  def follow_is_me?(as_type, actor_iri) do
    with {:follow_type, true} <-
           {:follow_type, is_or_extends?(as_type, "Follow")},
         {:activity_id, %URI{} = follow_id} <-
           {:activity_id, get_id(as_type)},
         {:activity_actor, %{values: values}} when is_list(values) <-
           {:activity_actor, Utils.get_actor(as_type)} do
      case is_me?(values, actor_iri) do
        {:error, reason} -> {:error, reason}
        true -> {:ok, follow_id}
        _ -> {:ok, nil}
      end
    else
      {:activity_id, _} ->
        {:error, Utils.err_id_required(activity: as_type)}

      {:activity_actor, _} ->
        {:error, Utils.err_actor_required(activity: as_type)}

      {:follow_type, _} ->
        {:error, "#{Utils.alias_module(as_type.__struct__)} is not a Follow type"}
    end
  end

  def is_me?(actor_iters, actor_iri, enabled \\ true)

  def is_me?(_actor_iters, _actor_iri, false), do: false

  def is_me?(actor_iters, %URI{} = actor_iri, _) when is_list(actor_iters) do
    actor_iri_str = URI.to_string(actor_iri)

    Enum.reduce_while(actor_iters, false, fn prop, acc ->
      case to_id(prop) do
        %URI{} = id ->
          if URI.to_string(id) == actor_iri_str do
            {:halt, true}
          else
            {:cont, acc}
          end

        _ ->
          {:halt, {:error, Utils.err_id_required(property: actor_iters)}}
      end
    end)
  end

  @doc """
  Implements the logic of adding object ids to a target Collection or
  OrderedCollection. This logic is shared by both the C2S and S2S protocols.
  """
  def add(context, object_prop, target_prop) do
    case to_id(target_prop) do
      %URI{} = coll_id ->
        Logger.error("adding to #{coll_id}")

        with :ok <- valid_collection_name?(coll_id),
             {:ok, object_ids} <-
               get_ids(object_prop),
             {:owns?, {:ok, true}} <-
               {:owns?, ActorFacade.db_owns?(context, coll_id)},
             {:ok, _oc} <-
               ActorFacade.db_update_collection(context, coll_id, %{add: object_ids}) do
          :ok
        else
          {:error, reason} ->
            {:error, reason}

          {:owns?, {:ok, _}} ->
            Logger.error("Local collection #{coll_id} not found")

            {:error,
             %Error{
               code: :unknown_collection,
               status: :unprocessable_entity,
               message: "Local collection #{coll_id} not found"
             }}

          {:owns?, {:error, reason}} ->
            {:error, reason}
        end

      _ ->
        {:error, Utils.err_target_required()}
    end
  end

  @doc """
  Implements the logic of removing object ids to a target Collection or
  OrderedCollection. This logic is shared by both the C2S and S2S protocols.
  """
  def remove(context, object_prop, target_prop) do
    case to_id(target_prop) do
      %URI{} = coll_id ->
        Logger.error("removing from #{coll_id}")

        with :ok <- valid_collection_name?(coll_id),
             {:ok, object_ids} <-
               get_ids(object_prop),
             {:owns?, {:ok, true}} <-
               {:owns?, ActorFacade.db_owns?(context, coll_id)},
             {:ok, _oc} <-
               ActorFacade.db_update_collection(context, coll_id, %{remove: object_ids}) do
          :ok
        else
          {:error, reason} ->
            {:error, reason}

          {:owns?, {:ok, _}} ->
            Logger.error("Local collection #{coll_id} not found")

            {:error,
             %Error{
               code: :unknown_collection,
               status: :unprocessable_entity,
               message: "Local collection #{coll_id} not found"
             }}

          {:owns?, {:error, reason}} ->
            {:error, reason}
        end

      _ ->
        {:error, Utils.err_target_required()}
    end
  end

  def valid_collection_name?(%URI{path: path} = _coll_id) do
    coll_name = Path.basename(path)

    if Enum.member?(@reserved_collection_names, coll_name) do
      reserved_names = Enum.join(@reserved_collection_names, ", ")
      {:error, "Collection cannot be one of #{reserved_names}"}
    else
      :ok
    end
  end

  @doc """
  Ensures the Create activity and its object have the same to,
  bto, cc, bcc, and audience properties. Copy the activity's recipients
  to objects, and the objects to the activity, but does NOT copy objects'
  recipients to each other.

  Ref: [AP Section 6.2](https://www.w3.org/TR/activitypub/#create-activity-outbox)
  When a Create activity is posted, the actor of the activity SHOULD be
  copied onto the object's attributedTo field.

  A mismatch between addressing of the Create activity and its object is
  likely to lead to confusion. As such, a server SHOULD copy any recipients
  of the Create activity to its object upon initial distribution, and
  likewise with copying recipients from the object to the wrapping Create
  activity.
  """
  def normalize_recipients(%{properties: activity_props} = activity) do
    # Phase 0: Acquire all recipients on the activity.
    # Obtain the actor_to, _bto, _cc, _bcc, and _audience maps
    with {:activity_object,
          %P.Object{alias: alias_, values: [%{member: object_value} | _]} = object}
         when is_struct(object_value) <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, activity_recipients_map} <- make_maps(activity) do
      %{properties: object_props} =
        new_value =
        ["to", "bto", "cc", "bcc", "audience"]
        |> Enum.reduce(object_value, fn prop_name, acc ->
          # Phase 1: Acquire all existing recipients on the object.
          {_prop, prop_iters, prop_mod, id_map} = property_and_id_map(object_value, prop_name)
          prop_map = Map.get(activity_recipients_map, prop_name, %{})
          # Phase 2: Apply missing recipients to the object from the activity.
          new_iters =
            Enum.reduce(prop_map, [], fn {k, v}, iter_acc ->
              if !Map.has_key?(id_map, k) do
                [Utils.new_iri_iter(prop_mod, v, alias_) | iter_acc]
              else
                iter_acc
              end
            end)

          if Enum.empty?(new_iters) do
            acc
          else
            Utils.append_iters(acc, prop_name, prop_iters ++ Enum.reverse(new_iters))
          end
        end)

      object = %P.Object{
        object
        | values: [%P.ObjectIterator{alias: alias_, member: new_value}]
      }

      # Phase 3: Copy (now complete) object recipients to the activity
      activity_props =
        ["to", "bto", "cc", "bcc", "audience"]
        |> Enum.reduce(activity_props, fn prop_name, acc ->
          copy_property(acc, object_props, prop_name)
        end)
        |> Map.put("object", object)

      {:ok, struct(activity, properties: activity_props)}
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  def make_maps(as_type) do
    ["to", "bto", "cc", "bcc", "audience"]
    |> Enum.reduce_while([], fn prop_name, acc ->
      case make_id_map(as_type, prop_name) do
        {:ok, map} -> {:cont, [{prop_name, map} | acc]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      elements when is_list(elements) ->
        {:ok, Map.new(elements)}
    end
  end

  @doc """
  Collects the 'inbox' and 'sharedInbox' IRIs from a list of actor types.
  """
  def get_inboxes(actors) when is_list(actors) do
    Enum.reduce_while(actors, [], fn actor, acc ->
      case get_inbox(actor) do
        %URI{} = inbox ->
          shared_inbox = get_shared_inbox(actor)
          {:cont, [{inbox, shared_inbox} | acc]}

        _ ->
          {:halt, {:error, "At least one Actor has no inbox"}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      iris -> {:ok, Enum.reverse(iris)}
    end
  end

  @doc """
  Extracts the 'sharedInbox' IRI from an actor type.
  "endpoints" is not in the vocabulary, so find it in the "unknown".
  """
  def get_shared_inbox(%{unknown: %{"endpoints" => %{"sharedInbox" => shared_inbox}}} = _actor)
      when is_binary(shared_inbox) do
    Utils.to_uri(shared_inbox)
  end

  def get_shared_inbox(_actor), do: nil

  @doc """
  Extracts the 'inbox' IRI from an actor property or type.
  """
  def get_inbox(values) when is_list(values) do
    Enum.map(values, &get_inbox(&1))
    |> Enum.reject(&is_nil/1)
  end

  def get_inbox(%{member: member}) when is_struct(member) do
    get_inbox(member)
  end

  def get_inbox(%{properties: properties} = value) when is_map(properties) do
    with true <- Utils.has_inbox?(value),
         %P.Inbox{} = inbox <- Map.get(properties, "inbox") do
      to_id(inbox)
    else
      _ ->
        id = Utils.get_json_ld_id(value)
        Logger.error("#{id} no inbox in props #{inspect(Map.keys(properties))}")
        nil
    end
  end

  def get_actor_id(activity, %{current_user: current_user}) when is_struct(activity) do
    case Utils.get_iri(activity, "actor") do
      %URI{} = id ->
        {:ok, id}

      _ ->
        if is_nil(current_user) || current_user.ap_id == "" do
          {:error, "No actor id in activity or context"}
        else
          {:ok, URI.parse(current_user.ap_id)}
        end
    end
  end

  def get_object_id(%{properties: properties}) when is_map(properties) do
    with %P.Object{values: [%P.ObjectIterator{} = prop]} <- Map.get(properties, "object"),
         %URI{} = id <- to_id(prop) do
      {:ok, id}
    else
      _ -> {:error, "No object id in activity"}
    end
  end

  def get_visibility(activity, %URI{path: actor_path} = actor_iri) do
    case get_recipients(activity, direct: true, as_map: true) do
      {:ok, recipients} ->
        to = Map.get(recipients, "to", []) |> List.wrap()
        cc = Map.get(recipients, "cc", []) |> List.wrap()
        followers_id = %URI{actor_iri | path: actor_path <> "/followers"}

        cond do
          Enum.any?(to, fn iri -> public?(iri) end) -> :public
          Enum.any?(cc, fn iri -> public?(iri) end) -> :unlisted
          Enum.member?(to ++ cc, followers_id) -> :followers_only
          true -> :direct
        end

      _ ->
        :direct
    end
  end

  @doc """
  Removes bto and bcc properties from the activity and its object.

  Note that this requirement of the specification is for the Social API,
  and not the Federating Protocol.

  Ref: [AP Section 6](https://www.w3.org/TR/activitypub/#client-to-server-interactions)
  The server MUST remove the bto and/or bcc properties, if they exist,
  from the ActivityStreams object before delivery, but MUST utilize the
  addressing originally stored on the bto / bcc properties for determining
  recipients in delivery.
  """
  def strip_hidden_recipients(%{__struct__: _, properties: properties} = activity) do
    activity =
      case Map.get(properties, "object") do
        %P.Object{values: object_iters} = object ->
          stripped_iters =
            Enum.map(object_iters, fn
              %{member: value} = object_prop when is_struct(value) ->
                value =
                  value
                  |> Utils.set_iri("bto", nil)
                  |> Utils.set_iri("bcc", nil)

                struct(object_prop, member: value)

              other ->
                other
            end)

          object = struct(object, values: stripped_iters)
          struct(activity, properties: Map.put(properties, "object", object))

        _ ->
          activity
      end

    activity
    |> Utils.set_iri("bto", nil)
    |> Utils.set_iri("bcc", nil)
  end

  def strip_hidden_recipients(m) when is_map(m) do
    # Same version for json
    m = Map.drop(m, ["bto", "bcc"])

    if is_nil(m["object"]) do
      m
    else
      List.wrap(m["object"])
      |> Enum.map(fn
        omap when is_map(omap) -> strip_hidden_recipients(omap)
        o -> o
      end)
      |> case do
        [] -> Map.delete(m, "object")
        [object] -> Map.put(m, "object", object)
        objects -> Map.put(m, "object", objects)
      end
    end
  end

  def verify_no_hidden_recipients(%{__struct__: _, properties: activity_props}) do
    if Map.has_key?(activity_props, "bto") || Map.has_key?(activity_props, "bcc") do
      {:halt, {:error, "Activity has hidden recipients"}}
    else
      case Map.get(activity_props, "object") do
        %P.Object{values: object_iters} ->
          Enum.reduce_while(object_iters, :ok, fn
            %{member: %{__struct__: _, properties: object_props}}, acc ->
              if Map.has_key?(object_props, "bto") || Map.has_key?(object_props, "bcc") do
                {:halt, {:error, "Object has hidden recipients"}}
              else
                {:cont, acc}
              end

            _non_member, acc ->
              {:cont, acc}
          end)

        _ ->
          :ok
      end
    end
  end

  def verify_no_hidden_recipients(nil, _label), do: :ok

  def verify_no_hidden_recipients(m, label) when is_map(m) do
    activity_keys = Map.keys(m)

    cond do
      "bto" in activity_keys || "bcc" in activity_keys ->
        {:error, "Leaking bto/bcc in #{label}"}

      is_nil(m["object"]) ->
        :ok

      true ->
        List.wrap(m["object"])
        |> Enum.reduce_while(:ok, fn
          omap, acc when is_map(omap) ->
            case verify_no_hidden_recipients(omap, "object") do
              {:error, reason} -> {:halt, {:error, reason}}
              :ok -> {:cont, acc}
            end

          _, acc ->
            {:cont, acc}
        end)
    end
  end

  @doc """
  Gather all the recipients contained in an ActivityStreams type or
  property, recursively.

  `opts` can contain one of these boolean flags:
  * `:to_only` - only gather 'to' property values
  * `:direct_only` - only gather 'to', 'cc', and 'audience' values
  * `:all` - gather 'to', 'bto', 'cc', 'bcc', and 'audience' values
  * `:as_map - return values in a map, keyed by property name

  `opts` can also contain an `:empty_ok` boolean flag. If not
  supplied or if false, `get_recpients/2` will return an error
  if it cannot find any recipients.
  """
  def get_recipients(prop_or_value, opts \\ [])

  def get_recipients(%{values: values} = _actor_or_object_prop, opts) do
    Enum.reduce_while(values, [], fn
      %{member: value}, acc when is_struct(value) ->
        case get_recipients(value, opts) do
          {:error, reason} -> {:halt, {:error, reason}}
          {:ok, recipients} -> {:cont, acc ++ recipients}
        end

      %{iri: %URI{} = iri}, acc ->
        {:cont, acc ++ [iri]}

      _, _ ->
        {:halt, {:error, "No type in actor property"}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      recipients -> {:ok, recipients}
    end
  end

  def get_recipients(%{properties: properties} = _as_value, opts) do
    prop_names =
      case Keyword.get(opts, :which, :all) do
        :to_only ->
          ["to"]

        :direct_only ->
          ["to", "cc", "audience"]

        _ ->
          ["to", "bto", "cc", "bcc", "audience"]
      end

    as_map = Keyword.get(opts, :as_map, false)

    Enum.reduce_while(prop_names, [], fn prop_name, acc ->
      case Map.get(properties, prop_name) do
        %{values: values} = prop when is_list(values) ->
          case get_ids(prop) do
            {:ok, ids} ->
              if as_map do
                {:cont, [{prop_name, ids} | acc]}
              else
                {:cont, acc ++ ids}
              end

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        _ ->
          {:cont, acc}
      end
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      [] ->
        if Keyword.get(opts, :empty_ok, false) do
          if as_map do
            {:ok, %{}}
          else
            {:ok, []}
          end
        else
          prop_names = Enum.join(prop_names, ", ")
          {:error, "No recipients found in #{prop_names}"}
        end

      recipients ->
        if as_map do
          {:ok, Map.new(recipients)}
        else
          {:ok, recipients}
        end
    end
  end

  def update_objects(%{properties: properties} = activity, update_fn) when is_map(properties) do
    # %T.Create{
    #   properties: %{
    #     "object" => %P.Object{
    #        values: [
    #          %P.ObjectIterator{
    #            member: %T.Note{
    case Utils.get_object(activity) do
      %P.Object{values: values} = object ->
        new_values =
          Enum.map(values, fn prop ->
            with value when is_struct(value) <- prop.member,
                 {:ok, new_value} <- update_fn.(value) do
              struct(prop, member: new_value)
            else
              _ ->
                prop
            end
          end)

        object = struct(object, values: new_values)
        {:ok, struct(activity, properties: Map.put(properties, "object", object))}

      _ ->
        Logger.warn("Activity has no object property, so no objects were updated")
        {:ok, activity}
    end
  end

  def update_object_collections(context, actor_iri, activity_id, object_ids, coll_name, op) do
    Enum.reduce_while(object_ids, :ok, fn %URI{path: object_path} = object_id, acc ->
      coll_id = %URI{object_id | path: Path.join(object_path, coll_name)}

      updates =
        case op do
          :add -> %{add: [{actor_iri, activity_id}]}
          :remove -> %{remove: [actor_iri]}
        end

      case ActorFacade.db_update_collection(context, coll_id, updates) do
        {:error, reason} -> {:halt, {:error, reason}}
        _ -> {:cont, acc}
      end
    end)
  end

  @doc """
  Forms an ActivityPub id based on the HTTP request.

  Specifying an `:endpoint_url` with a given scheme, host, and port in the
  Application configuration allows for retrieving ActivityStreams content with
  identifiers such as HTTP, HTTPS, or other protocol schemes.
  """
  def request_id(
        %Plug.Conn{request_path: path, query_string: query},
        endpoint_url \\ nil
      ) do
    # NOTE: The Phoenix.Test.Adapter inserts a "www." prefix in conn.host and
    # changes conn.scheme from "https" to "http", so we need to use the endpoint_url
    # argument to fix things.
    endpoint_url = endpoint_url || Fedi.Application.endpoint_url()
    endpoint_uri = Utils.to_uri(endpoint_url)

    query =
      if query == "" do
        nil
      else
        query
      end

    %URI{endpoint_uri | path: path, query: query}
  end

  @doc """
  Sanitize query params for collection URLs
  """
  def collection_opts(params, conn_or_ap_id \\ nil)

  def collection_opts(params, %Plug.Conn{} = conn) when is_map(params) do
    case conn.assigns[:current_user] do
      %{ap_id: ap_id} -> collection_opts(params, ap_id)
      _ -> collection_opts(params, nil)
    end
  end

  def collection_opts(params, ap_id) when is_map(params) and is_binary(ap_id) do
    collection_opts(params, nil)
    |> Keyword.put(:visible_to, ap_id)
  end

  def collection_opts(params, nil) when is_map(params) do
    [:max_id, :min_id, :page, :first, :page_size]
    |> Enum.reduce([], fn key, acc ->
      case {key, Map.get(params, Atom.to_string(key))} do
        {_, nil} ->
          nil

        {_, v} when not is_binary(v) ->
          Logger.error("collection_opts skipping non-binary #{key} #{inspect(v)}")
          nil

        {:page_size, v} ->
          case Integer.parse(v) do
            {i, ""} -> i
            _ -> nil
          end

        {:page, v} ->
          if v != "" && v != "false" do
            true
          else
            nil
          end

        {:first, v} ->
          if v == "true" do
            true
          else
            nil
          end

        {_, v} ->
          v
      end
      |> case do
        nil -> acc
        v -> Keyword.put(acc, key, v)
      end
    end)
  end
end
