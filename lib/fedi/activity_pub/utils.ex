defmodule Fedi.ActivityPub.Utils do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Error
  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T

  @content_type_header "content-type"
  @accept_header "accept"
  @content_type_value "application/ld+json; profile=\"https:www.w3.org/ns/activitystreams\""
  @public_activity_streams "https://www.w3.org/ns/activitystreams#Public"
  @public_activity_streams_iri URI.parse(@public_activity_streams)
  @public_json_ld "Public"
  @public_json_ld_as "as:Public"

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
      {:error, reason} ->
        Logger.error("bad body #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Returns the IRI that indicates an Activity is meant
  to be visible for general public consumption.
  """
  def public_activity_streams_iri, do: @public_activity_streams_iri

  @doc """
  Determines if an IRI string is the Public collection as defined in
  the spec, including JSON-LD compliant collections.

  Ref: [AP Section 5.6](https://www.w3.org/TR/activitypub/#public-addressing)
  """
  def public?(%URI{} = iri) do
    public?(URI.to_string(iri))
  end

  def public?(str) when is_binary(str) do
    str == @public_activity_streams ||
      str == @public_json_ld ||
      str == @public_json_ld_as
  end

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
  def get_ids(%{values: values}) do
    Enum.reduce_while(values, [], fn prop, acc ->
      case to_id(prop) do
        %URI{} = id -> {:cont, [id | acc]}
        _ -> {:halt, {:error, "No id or IRI was set"}}
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
         %Fedi.ActivityStreams.Property.Href{xsd_any_uri_member: %URI{} = href} <-
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
                {[member | type_acc2], iri_acc2}

              %{iri: %URI{} = iri}, {type_acc2, iri_acc2} ->
                {type_acc2, [iri | iri_acc2]}

              _, acc2 ->
                acc2
            end)

          {type_acc ++ types, iri_acc ++ iris}

        %{member: member} when is_struct(member) ->
          {[member | type_acc], iri_acc}

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
  def wrap_in_create(%{properties: properties} = object, %URI{} = actor_iri)
      when is_map(properties) do
    # Object Property
    object_prop = %P.Object{alias: "", values: [%P.ObjectIterator{alias: "", member: object}]}

    # Actor Property
    actor_prop = %P.Actor{alias: "", values: [%P.ActorIterator{alias: "", iri: actor_iri}]}

    create_props = %{"object" => object_prop, "actor" => actor_prop}

    # Copying over properties
    create_props =
      ["published", "to", "bto", "cc", "bcc", "audience"]
      |> Enum.reduce(create_props, fn prop_name, acc ->
        copy_property(acc, properties, prop_name)
      end)

    %T.Create{alias: "", properties: create_props}
  end

  def copy_property(dest, source, prop_name) do
    case {Map.get(source, prop_name), prop_name} do
      {%{xsd_date_time_member: %DateTime{} = published}, "published"} ->
        Map.put(dest, prop_name, %P.Published{
          alias: "",
          xsd_date_time_member: published,
          has_date_time_member?: true
        })

      {%{values: [%{iri: _} = iter_prop | _]}, "to"} ->
        case to_id(iter_prop) do
          %URI{} = id ->
            Map.put(dest, prop_name, %P.To{
              alias: "",
              values: [%P.ToIterator{alias: "", iri: id}]
            })

          _ ->
            dest
        end

      {%{values: [%{iri: _} = iter_prop | _]}, "bto"} ->
        case to_id(iter_prop) do
          %URI{} = id ->
            Map.put(dest, prop_name, %P.Bto{
              alias: "",
              values: [%P.BtoIterator{alias: "", iri: id}]
            })

          _ ->
            dest
        end

      {%{values: [%{iri: _} = iter_prop | _]}, "cc"} ->
        case to_id(iter_prop) do
          %URI{} = id ->
            Map.put(dest, prop_name, %P.Cc{
              alias: "",
              values: [%P.CcIterator{alias: "", iri: id}]
            })

          _ ->
            dest
        end

      {%{values: [%{iri: _} = iter_prop | _]}, "bcc"} ->
        case to_id(iter_prop) do
          %URI{} = id ->
            Map.put(dest, prop_name, %P.Bcc{
              alias: "",
              values: [%P.BccIterator{alias: "", iri: id}]
            })

          _ ->
            dest
        end

      {%{values: [%{iri: _} = iter_prop | _]}, "audience"} ->
        case to_id(iter_prop) do
          %URI{} = id ->
            Map.put(dest, prop_name, %P.Audience{
              alias: "",
              values: [%P.AudienceIterator{alias: "", iri: id}]
            })

          _ ->
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
        {:error, "No orderedItems in collection"}
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
      {@content_type_header, @content_type_value},
      # RFC 7231 §7.1.1.2
      {"date", date_header_value()},
      # RFC 3230 and RFC 5843
      {"digest", digest}
    ]
    |> Enum.reduce(conn, fn {key, value}, acc ->
      Plug.Conn.put_resp_header(acc, key, value)
    end)
  end

  def send_json_resp(%Plug.Conn{} = conn, status, %Error{} = error) do
    send_json_resp(conn, status, Error.response_message(error))
  end

  def send_json_resp(%Plug.Conn{} = conn, status, body) when is_binary(body) do
    conn
    |> Plug.Conn.put_resp_header(@content_type_header, "application/json")
    |> Plug.Conn.send_resp(status, body)
  end

  def send_json_resp(%Plug.Conn{} = conn, status, %Error{} = error, actor_state) do
    send_json_resp(conn, status, Error.response_message(error), actor_state)
  end

  def send_json_resp(%Plug.Conn{} = conn, status, body, actor_state) when is_binary(body) do
    conn
    |> Plug.Conn.put_private(:actor_state, actor_state)
    |> Plug.Conn.put_resp_header(@content_type_header, "application/json")
    |> Plug.Conn.send_resp(status, body)
  end

  def get_type_meta(%{__struct__: module}) do
    with mod_parts <- Module.split(module),
         {["Fedi", _namespace], ["Type", _type]} <- Enum.split(mod_parts, -2) do
      Module.concat(mod_parts ++ ["Meta"])
    else
      _ -> nil
    end
  end

  # TODO ONTOLOGY Change to one function call, `metadata(:is_or_extends?)`
  def is_or_extends?(as_value, type_name) do
    case get_type_meta(as_value) do
      nil ->
        false

      meta ->
        if type_name == apply(meta, :type_name, []) do
          true
        else
          meta
          |> apply(:extends, [])
          |> Enum.member?(type_name)
        end
    end
  end

  @doc """
  Verifies that a value is an Activity with a valid id.
  """
  def valid_activity?(as_value) when is_struct(as_value) do
    if is_or_extends?(as_value, "Activity") do
      case Utils.get_json_ld_id(as_value) do
        %URI{} = id ->
          {:ok, as_value, id}

        _ ->
          {:error, Utils.err_id_required(value: as_value)}
      end
    else
      {:error, "#{as_value.__struct__} is not an Activity"}
    end
  end

  def valid_activity?(as_value) do
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

  def make_id_map(other) do
    {:error, "make_id_map not implmented on #{inspect(other)}"}
  end

  def property_and_id_map(%{properties: properties}, prop_name) do
    case Map.get(properties, prop_name) do
      %{__struct__: module, values: iters} = prop -> {prop, iters, module, make_id_map(prop)}
      _ -> {nil, [], Utils.property_module(prop_name), %{}}
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
          xsd_string_member: type_name,
          has_string_member?: true
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
         {:activity_object, %P.Object{values: [_ | _] = values} = object_prop} <-
           {:activity_object, Utils.get_object(activity)} do
      Enum.reduce_while(values, {:ok, object_prop}, fn prop, acc ->
        case to_id(prop) do
          %URI{host: host} = object_id ->
            if host == origin_host do
              {:cont, acc}
            else
              {:halt, {:error, "Object #{URI.to_string(object_id)} is not in activity origin"}}
            end

          _ ->
            {:halt, {:error, Utils.err_id_required(iters: values)}}
        end
      end)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_id, _} -> Utils.err_id_required(activity: activity)
    end
  end

  @doc """
  Returns :ok if the actors on types in
  the 'object' property are all listed in the 'actor' property.
  """
  def object_actors_match_activity_actors?(
        %{database: database} = context,
        activity
      ) do
    with {:ok, box_iri, app_agent} <-
           get_dereference_data(context),
         {:activity_id, %URI{}} <- {:activity_id, get_id(activity)},
         {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_actor, %P.Actor{values: _} = actor_prop} when is_list(values) <-
           {:activity_actor, Utils.get_actor(activity)},
         {:ok, actor_ids} <- get_ids(actor_prop),
         actor_ids <- MapSet.new(actor_ids) do
      Enum.reduce_while(values, :ok, fn prop, acc ->
        with {:object_id, %URI{} = iri} <- {:object_id, to_id(prop)},
             # Attempt to dereference the IRI, regardless whether it is a
             # type or IRI
             {:ok, m} <- apply(database, :dereference, [box_iri, app_agent, iri]),
             {:ok, actor_type} <- Fedi.Streams.JSONResolver.resolve(m),
             {:object_actor, %{values: _} = object_actor_prop} when is_list(values) <-
               {:object_actor, Utils.get_actor(actor_type)},
             {:ok, object_actor_ids} <- get_ids(object_actor_prop),
             object_actor_ids <- MapSet.new(object_actor_ids) do
          if MapSet.subset?(actor_ids, object_actor_ids) do
            {:cont, acc}
          else
            {:halt, {:error, "Activity does not have all actors from its object's actors"}}
          end
        else
          {:object_id, _} ->
            {:halt, {:error, Utils.err_id_required(activity: activity)}}

          {:object_actor, _} ->
            {:halt, {:error, Utils.err_actor_required(activity: activity)}}
        end
      end)
    else
      {:error, reason} -> {:error, reason}
      {:activity_id, _} -> Utils.err_id_required(activity: activity)
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
      {:actor_ids, _} -> {:error, "No id in activity's actor"}
      {_, {:error, reason}} -> {:error, reason}
    end
  end

  def get_dereference_data(%{data: %{box_iri: box_iri, app_agent: app_agent}}) do
    {:ok, box_iri, app_agent}
  end

  def get_dereference_data(%{data: _} = context) do
    Logger.error("No inbox or outbox in #{inspect(context)}")
    {:error, "Internal server error"}
  end

  def get_dereference_data(context) do
    Logger.error("No data in #{inspect(context)}")
    {:error, "Internal server error"}
  end

  @doc """
  Implements the logic of adding object ids to a target Collection or
  OrderedCollection. This logic is shared by both the C2S and S2S protocols.
  """
  def add(database, object_prop, target_prop) do
    with {:ok, op_ids} <- get_ids(object_prop),
         {:ok, target_ids} <- get_ids(target_prop) do
      Enum.reduce_while(target_ids, :ok, fn target_id, acc ->
        with {:owns, {:ok, true}} <- {:owns, apply(database, :owns, [target_id])},
             {:ok, as_value} <- apply(database, :get, [target_id]) do
          cond do
            is_or_extends?(as_value, "OrderedCollection") ->
              Utils.append_iris(as_value, "orderedItems", op_ids)

            is_or_extends?(as_value, "Collection") ->
              Utils.append_iris(as_value, "items", op_ids)

            true ->
              {:error, "Target in Add is neither a Collection nor an OrderedCollection"}
          end
          |> case do
            {:error, reason} ->
              {:halt, {:error, reason}}

            updated_value ->
              case apply(database, :update, [updated_value]) do
                {:error, reason} -> {:halt, {:error, reason}}
                {:ok, _updated, _raw_json} -> {:cont, acc}
              end
          end
        else
          {:error, reason} -> {:halt, {:error, reason}}
          {:owns, {:ok, _}} -> {:cont, acc}
          {:owns, {:error, reason}} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  @doc """
  Implements the logic of removing object ids to a target Collection or
  OrderedCollection. This logic is shared by both the C2S and S2S protocols.
  """
  def remove(database, object_prop, target_prop) do
    with {:ok, op_ids} <- get_ids(object_prop),
         {:ok, target_ids} <- get_ids(target_prop) do
      Enum.reduce_while(target_ids, :ok, fn target_id, acc ->
        with {:owns, {:ok, true}} <- {:owns, apply(database, :owns, [target_id])},
             {:ok, as_value} <- apply(database, :get, [target_id]) do
          cond do
            is_or_extends?(as_value, "OrderedCollection") ->
              Utils.remove_iris(as_value, "orderedItems", op_ids)

            is_or_extends?(as_value, "Collection") ->
              Utils.remove_iris(as_value, "items", op_ids)

            true ->
              {:error, "Target in Add is neither a Collection nor an OrderedCollection"}
          end
          |> case do
            {:error, reason} ->
              {:halt, {:error, reason}}

            updated_value ->
              case apply(database, :update, [updated_value]) do
                {:error, reason} -> {:halt, {:error, reason}}
                {:ok, _updated, _raw_json} -> {:cont, acc}
              end
          end
        else
          {:error, reason} -> {:halt, {:error, reason}}
          {:owns, {:ok, _}} -> {:cont, acc}
          {:owns, {:error, reason}} -> {:halt, {:error, reason}}
        end
      end)
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
  def normalize_recipients(activity) when is_struct(activity) do
    # Phase 0: Acquire all recipients on the activity.
    # Obtain the actor_to, _bto, _cc, _bcc, and _audience maps

    ["to", "bto", "cc", "bcc", "audience"]
    |> Enum.reduce_while([], fn prop_name, acc ->
      case make_id_map(activity, prop_name) do
        {:ok, map} -> {:cont, [{prop_name, map} | acc]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      elements when is_list(elements) ->
        with {:activity_object, %P.Object{alias: alias_, values: [%{member: value} | _]} = object}
             when is_struct(value) <-
               {:activity_object, Utils.get_object(activity)},
             actor_maps <- Map.new(elements) do
          # Obtain the objects maps for each recipient type.
          {new_value, object_maps} =
            ["to", "bto", "cc", "bcc", "audience"]
            |> Enum.reduce({value, %{}}, fn prop_name, {acc, m} ->
              # Phase 1: Acquire all existing recipients on the object.
              {_prop, prop_iters, prop_mod, id_map} = property_and_id_map(value, prop_name)
              actor_map = actor_maps[prop_name]

              # Phase 2: Apply missing recipients to the object from the activity.
              new_iters =
                Enum.reduce(actor_map, [], fn {k, v}, iter_acc ->
                  if !Map.has_key?(id_map, k) do
                    [Utils.new_iri_iter(prop_mod, v, alias_) | iter_acc]
                  else
                    iter_acc
                  end
                end)

              if Enum.empty?(new_iters) do
                {acc, m}
              else
                updated_value =
                  Utils.append_iters(acc, prop_name, prop_iters ++ Enum.reverse(new_iters))

                {updated_value, Map.put(m, prop_name, id_map)}
              end
            end)

          new_object = %P.Object{
            object
            | values: [%P.ObjectIterator{alias: alias_, member: new_value}]
          }

          activity =
            struct(activity, properties: Map.put(activity.properties, "object", new_object))

          # Phase 3: Apply missing recipients to the activity from the objects.
          activity =
            ["to", "bto", "cc", "bcc", "audience"]
            |> Enum.reduce(activity, fn prop_name, acc ->
              {_prop, prop_iters, prop_mod, id_map} = property_and_id_map(activity, prop_name)
              object_map = Map.get(object_maps, prop_name, %{})

              new_iters =
                Enum.reduce(object_map, [], fn {k, v}, iter_acc ->
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

          {:ok, activity}
        else
          {:activity_object, _} -> Utils.err_object_required(activity: activity)
        end
    end
  end

  @doc """
  Collects the 'inbox' IRIs from a list of actor values.
  """
  def get_inboxes(actors) when is_list(actors) do
    Enum.reduce_while(actors, [], fn actor, acc ->
      case get_inbox(actor) do
        %URI{} = iri ->
          {:cont, [iri | acc]}

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
  Extracts the 'inbox' IRI from an actor property or type.
  """
  def get_inbox(values) when is_list(values) do
    Enum.map(values, &get_inbox(&1))
    |> Enum.filter(fn i -> !is_nil(i) end)
  end

  def get_inbox(%{member: member}) when is_struct(member) do
    get_inbox(member)
  end

  def get_inbox(%{properties: properties} = value) when is_map(properties) do
    with true <- Utils.has_inbox?(value),
         %Fedi.ActivityStreams.Property.Inbox{} = inbox <-
           Map.get(properties, "inbox") do
      to_id(inbox)
    else
      _ -> nil
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
  def strip_hidden_recipients(%{properties: properties} = activity) do
    activity =
      case Map.get(properties, "object") do
        %Fedi.ActivityStreams.Property.Object{values: [%{member: value} | _]} = object_prop
        when is_struct(value) ->
          value =
            value
            |> Utils.set_iri("bto", nil)
            |> Utils.set_iri("bcc", nil)

          struct(activity,
            properties:
              Map.put(properties, "object", %Fedi.ActivityStreams.Property.Object{
                object_prop
                | values: [value]
              })
          )

        _ ->
          activity
      end

    activity
    |> Utils.set_iri("bto", nil)
    |> Utils.set_iri("bcc", nil)
  end

  def get_attributed_to(%{properties: properties} = _as_value) do
    case Map.get(properties, "attributedTo") do
      %{values: [%{iri: %URI{} = iri}]} ->
        iri

      _ ->
        nil
    end
  end

  @doc """
  Gather all the recipients contained in an ActivityStreams type or
  property, recursively.

  `opts` can contain one of these boolean flags:
  * `:to_only` - only gather "to" property values
  * `:direct_only` - only gather "to", "cc" and "audience" values
  * `:all` - gather "to", "bto", "cc", "bcc" and "audience" values

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

    Enum.reduce_while(prop_names, [], fn prop_name, acc ->
      case Map.get(properties, prop_name) do
        %{values: values} = prop when is_list(values) ->
          case get_ids(prop) do
            {:ok, ids} -> {:cont, acc ++ ids}
            {:error, reason} -> {:halt, {:error, reason}}
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
          {:ok, []}
        else
          prop_names = Enum.join(prop_names, ", ")
          {:error, "No recipients found in #{prop_names}"}
        end

      recipients ->
        {:ok, recipients}
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

        new_object = struct(object, values: new_values)
        {:ok, struct(activity, properties: Map.put(properties, "object", new_object))}

      _ ->
        Logger.warn("Activity has no object property, so no objects were updated")
        {:ok, activity}
    end
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
    endpoint_uri = URI.parse(endpoint_url)

    query =
      if query == "" do
        nil
      else
        query
      end

    %URI{endpoint_uri | path: path, query: query}
  end
end
