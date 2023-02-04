defmodule Fedi.Streams.Utils do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Error
  alias Fedi.W3IDSecurityV1.Property.{PublicKey, PublicKeyPem}

  # TODO ONTOLOGY
  @activity_types [
    "Accept",
    "Activity",
    "Add",
    "Announce",
    "Arrive",
    "Block",
    "Create",
    "Delete",
    "Dislike",
    "Flag",
    "Follow",
    "Ignore",
    "IntransitiveActivity",
    "Invite",
    "Join",
    "Leave",
    "Like",
    "Listen",
    "Move",
    "Offer",
    "Question",
    "Read",
    "Reject",
    "Remove",
    "TentativeAccept",
    "TentativeReject",
    "Travel",
    "Undo",
    "Update",
    "View"
  ]
  @actor_types ["Application", "Group", "Organization", "Person", "Service"]
  @document_types ["Audio", "Document", "Page", "Image", "Video"]
  @post_types ["Article", "Note"]
  @link_types ["Link", "Mention"]
  @collection_types ["Collection", "CollectionPage", "OrderedColletion", "OrderedCollectionPage"]

  ### Errors

  @doc """
  Indicates that the activity needs its 'actor' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_actor_required(data \\ []) do
    suffix = err_location(data)
    Error.new(:actor_required, "Actor property required#{suffix}", :unprocessable_entity, data)
  end

  @doc """
  Indicates that the activity needs its 'object' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_object_required(data \\ []) do
    suffix = err_location(data)
    Error.new(:object_required, "Object property required#{suffix}", :unprocessable_entity, data)
  end

  @doc """
  Indicates that the activity needs its 'target' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_target_required(data \\ []) do
    suffix = err_location(data)
    Error.new(:target_required, "Target property required#{suffix}", :unprocessable_entity, data)
  end

  @doc """
  Indicates that the activity needs its 'id' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_id_required(data \\ []) do
    suffix = err_location(data)
    Error.new(:id_required, "Id property required#{suffix}", :unprocessable_entity, data)
  end

  @doc """
  Indicates that the activity needs its 'type' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_type_required(data \\ []) do
    suffix = err_location(data)
    Error.new(:type_required, "Type property required#{suffix}", :unprocessable_entity, data)
  end

  @doc """
  Indicates that the activity needs its 'type' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_type_not_an_activity(type_name, data \\ []) do
    Error.new(
      :type_not_an_activity,
      "Type #{type_name} is not an Activity",
      :unprocessable_entity,
      data
    )
  end

  @doc """
  Indicates that an ActivityStreams value has a type that is not
  handled by the JSONResolver.
  """
  def err_unhandled_type(message, data \\ []) do
    Error.new(:unhandled_type, message, :internal_server_error, data)
  end

  @doc """
  Indicates that an exception was raised during serialization.
  """
  def err_serialization(message, data \\ []) do
    Error.new(:serialization, message, :internal_server_error, data)
  end

  @doc """
  Indicates that there no actor actor has been authenticated.
  """
  def err_actor_unauthenticated(data \\ []) do
    Error.new(
      :actor_unauthenticated,
      "No actor is authenticated for this request",
      :unauthorized,
      data
    )
  end

  @doc """
  Indicates that the actor is not authorized to perform
  the operation.
  """
  def err_actor_unauthorized(data \\ []) do
    Error.new(:actor_unauthorized, "Actor is not authorized for this request", :forbidden, data)
  end

  def err_location([]), do: ""

  def err_location(data) do
    cond do
      Keyword.has_key?(data, :activity) ->
        %{__struct__: module} = Keyword.get(data, :activity)
        " on activity #{alias_module(module)}"

      Keyword.has_key?(data, :value) ->
        %{__struct__: module} = Keyword.get(data, :value)
        " on type #{alias_module(module)}"

      Keyword.has_key?(data, :iters) ->
        case Keyword.get(data, :iters) do
          [%{__struct__: module} | _] ->
            " on property #{alias_module(module)}"

          _ ->
            ""
        end

      true ->
        ""
    end
  end

  def capitalize(str) do
    {head, rest} = String.split_at(str, 1)
    String.upcase(head) <> rest
  end

  # TODO ONTOLOGY
  def property_module(prop_name) when is_binary(prop_name) do
    Module.concat(["Fedi", "ActivityStreams", "Property", capitalize(prop_name)])
  end

  # On a non-functional property
  def iterator_module(%{__struct__: module, values: _}), do: iterator_module(module)

  # On a non-functional module
  def iterator_module(module) when is_atom(module) do
    Module.split(module)
    |> List.update_at(-1, fn name ->
      if String.ends_with?(name, "Iterator") do
        name
      else
        name <> "Iterator"
      end
    end)
    |> Module.concat()
  end

  def base_module(module) when is_atom(module) do
    Module.split(module)
    |> List.update_at(-1, fn name -> String.replace_trailing(name, "Iterator", "") end)
    |> Module.concat()
  end

  def alias_module(module) when is_atom(module) do
    Module.split(module) |> List.last()
  end

  # prop like:
  # %Fedi.ActivityStreams.Property.OrderedItemsIterator{
  #   alias: "",
  #   iri: nil,
  #   member: %Fedi.ActivityStreams.Type.Note{
  #     alias: "",
  #     properties: %{
  #       "id" => %Fedi.JSONLD.Property.Id{xsd_any_uri_member: %URI{...}},
  #     }
  #   }
  # }

  ### Generic getter and setter

  # On a non-functional property
  def get_prop(%{values: []}, _as_type_get_prop_fn) do
    nil
  end

  def get_prop(%{values: [prop | _]}, as_type_get_prop_fn) do
    get_prop(prop, as_type_get_prop_fn)
  end

  # On a functional property
  def get_prop(%{member: nil}, _as_type_get_prop_fn) do
    nil
  end

  def get_prop(%{member: member}, as_type_get_prop_fn) when is_struct(member) do
    as_type_get_prop_fn.(member)
  end

  # On a type
  def get_prop(%{properties: properties} = as_type, as_type_get_prop_fn)
      when is_map(properties) do
    as_type_get_prop_fn.(as_type)
  end

  def get_prop(_, _), do: nil

  # On a non-functional property
  def set_prop(%{values: [iter | rest]} = prop, v, as_type_set_prop_fn) do
    case set_prop(iter, v, as_type_set_prop_fn) do
      {:ok, new_iter} ->
        {:ok, struct(prop, values: [new_iter | rest])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # On a functional property
  def set_prop(%{member: nil}, _v, _as_type_set_prop_fn) do
    {:error, "No type value in property"}
  end

  def set_prop(%{member: member} = value, v, as_type_set_prop_fn) when is_struct(member) do
    {:ok, struct(value, member: as_type_set_prop_fn.(member, v))}
  end

  # On a type
  def set_prop(%{properties: properties} = as_type, v, as_type_set_prop_fn)
      when is_map(properties) do
    {:ok, as_type_set_prop_fn.(as_type, v)}
  end

  def set_prop(_, _, _), do: {:error, "Not a type or property"}

  ### Specific getters and setters

  def get_json_ld_id(prop_or_type), do: get_prop(prop_or_type, &as_type_get_json_ld_id/1)

  def as_type_get_json_ld_id(%{properties: properties}) when is_map(properties) do
    # A type with properties
    case Map.get(properties, "id") do
      %Fedi.JSONLD.Property.Id{xsd_any_uri_member: %URI{} = id} ->
        id

      _ ->
        nil
    end
  end

  def set_json_ld_id(prop_or_type, %URI{} = id),
    do: set_prop(prop_or_type, id, &as_type_set_json_ld_id/2)

  def as_type_set_json_ld_id(%{properties: properties} = as_type, %URI{} = id)
      when is_struct(as_type) do
    struct(as_type, properties: Map.put(properties, "id", Fedi.JSONLD.Property.Id.new_id(id)))
  end

  def get_json_ld_type(prop_or_type), do: get_prop(prop_or_type, &as_type_get_json_ld_type/1)

  # On a type
  def as_type_get_json_ld_type(%{properties: properties}) when is_map(properties) do
    with %Fedi.JSONLD.Property.Type{
           values: [
             %Fedi.JSONLD.Property.TypeIterator{
               xsd_string_member: type
             }
             | _
           ]
         } <-
           Map.get(properties, "type") do
      type
    else
      _ ->
        nil
    end
  end

  def set_json_ld_type(prop_or_type, type) when is_binary(type),
    do: set_prop(prop_or_type, type, &as_type_set_json_ld_type/2)

  # On a type
  def as_type_set_json_ld_type(%{properties: properties} = as_type, type)
      when is_map(properties) and is_binary(type) do
    struct(as_type,
      properties: Map.put(properties, "type", Fedi.JSONLD.Property.Type.new_type(type))
    )
  end

  def set_context(%{unknown: unknown} = type, context)
      when is_binary(context) or is_list(context) do
    struct(type, unknown: Map.put(unknown || %{}, "@context", context))
  end

  def set_context(%{unknown: unknown} = type, _simple) do
    struct(type,
      unknown: Map.put(unknown || %{}, "@context", "https://www.w3.org/ns/activitystreams")
    )
  end

  def get_id_type_name_and_category(as_value) do
    with %URI{} = id = get_json_ld_id(as_value),
         {:ok, type_name, category} <- get_type_name_and_category(as_value) do
      {:ok, id, type_name, category}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, err_id_required(value: as_value)}
    end
  end

  def get_type_name_and_category(as_value) do
    case get_json_ld_type(as_value) do
      type_name when is_binary(type_name) ->
        {:ok, type_name, get_type_category(type_name)}

      _ ->
        {:error, err_type_required(value: as_value)}
    end
  end

  # TODO ONTOLOGY
  def get_type_category(type_name) when is_binary(type_name) do
    cond do
      Enum.member?(@actor_types, type_name) -> :actors
      Enum.member?(@activity_types, type_name) -> :activities
      Enum.member?(@document_types, type_name) -> :documents
      Enum.member?(@post_types, type_name) -> :posts
      Enum.member?(@link_types, type_name) -> :links
      Enum.member?(@collection_types, type_name) -> :collections
      true -> :objects
    end
  end

  # TODO ONTOLOGY

  # On a functional property
  def has_inbox?(%{member: member}) when is_struct(member) do
    has_inbox?(member)
  end

  # On a type
  def has_inbox?(%{properties: _properties} = value) do
    case get_json_ld_type(value) do
      nil ->
        false

      type when is_binary(type) ->
        Enum.member?(@actor_types, type)

      types when is_list(types) ->
        intersects =
          MapSet.intersection(MapSet.new(@actor_types), MapSet.new(types))
          |> MapSet.to_list()

        !Enum.empty?(intersects)
    end
  end

  # TODO ONTOLOGY

  # On a functional property
  def has_href?(%{member: member}) when is_struct(member) do
    has_href?(member)
  end

  # On a type
  def has_href?(%{properties: properties} = value) when is_map(properties) do
    case get_json_ld_type(value) do
      nil ->
        false

      type when is_binary(type) ->
        Enum.member?(@link_types, type)

      types when is_list(types) ->
        intersects =
          MapSet.intersection(MapSet.new(@link_types), MapSet.new(types))
          |> MapSet.to_list()

        !Enum.empty?(intersects)
    end
  end

  def has_href?(_other) do
    false
  end

  # On a type
  def get_actor_or_attributed_to_iri(activity) do
    case get_iri(activity, "actor") || get_iri(activity, "attributedTo") do
      %URI{} = actor_id ->
        actor_id

      _ ->
        case get_object(activity) do
          object when is_struct(object) ->
            get_iri(object, "attributedTo")

          _ ->
            nil
        end
    end
  end

  # On a non-functional property
  def get_iri(%{values: [%{iri: %URI{} = iri} | _]}), do: iri

  # On a functional property
  def get_iri(%{iri: %URI{} = iri}), do: iri

  def get_iri(_), do: nil

  # On a non-functional property
  def get_iri(%{values: [iter | _]}, prop_name) do
    get_iri(iter, prop_name)
  end

  # On a functional property
  def get_iri(%{member: member}, prop_name) when is_struct(member) do
    get_iri(member, prop_name)
  end

  # On a type
  def get_iri(%{properties: properties}, prop_name) when is_map(properties) do
    case Map.get(properties, prop_name) do
      prop when is_struct(prop) -> get_iri(prop)
      _ -> nil
    end
  end

  def get_iri(_, _prop_name), do: nil

  # On a non-functional property
  def set_iri(%{values: [iter | rest]} = prop, prop_name, iri_or_nil) do
    new_iter = set_iri(iter, prop_name, iri_or_nil)
    struct(prop, values: [new_iter | rest])
  end

  # On a functional property
  def set_iri(%{member: member} = value, prop_name, iri_or_nil) when is_struct(member) do
    new_member = set_iri(member, prop_name, iri_or_nil)
    struct(value, member: new_member)
  end

  # On a type
  def set_iri(%{properties: properties} = value, prop_name, nil) do
    struct(value, properties: Map.delete(properties, prop_name))
  end

  # On a type
  def set_iri(%{alias: alias_, properties: properties} = value, prop_name, %URI{} = v) do
    prop_or_mod =
      case Map.get(properties, prop_name) do
        %{__struct__: _, values: [%{iri: _} | _]} = prop ->
          prop

        nil ->
          property_module(prop_name)
      end

    iterator_mod = iterator_module(prop_or_mod)
    new_values = [struct(iterator_mod, alias: alias_, iri: v)]
    prop = struct(prop_or_mod, alias: alias_, values: new_values)
    struct(value, properties: Map.put(properties, prop_name, prop))
  end

  def append_iris(value, _prop_name, []), do: value

  # On a type
  def append_iris(%{alias: alias_, properties: _properties} = value, prop_name, iris) do
    iters = Enum.map(iris, fn iri -> new_iri_iter(prop_name, iri, alias_) end)
    append_iters(value, prop_name, iters)
  end

  def append_iters(value, _prop_name, []), do: value

  # On a functional property
  def append_iters(%{values: [iter | rest]} = prop, prop_name, iters) do
    new_iter = append_iters(iter, prop_name, iters)
    struct(prop, values: [new_iter | rest])
  end

  # On a non-functional property
  def append_iters(%{member: member} = prop, prop_name, iters) when is_struct(member) do
    new_member = append_iters(member, prop_name, iters)
    struct(prop, member: new_member)
  end

  # On type
  def append_iters(%{alias: alias_, properties: properties} = value, prop_name, iters)
      when is_map(properties) and is_list(iters) do
    prop =
      case Map.get(properties, prop_name) do
        %{values: values} = prop ->
          struct(prop, values: values ++ iters)

        nil ->
          module = property_module(prop_name)
          struct(module, alias: alias_, values: iters)
      end

    struct(value, properties: Map.put(properties, prop_name, prop))
  end

  def append_iri(%{properties: properties} = value, prop_name, %URI{} = v, alias \\ "") do
    prop =
      case Map.get(properties, prop_name) do
        %{values: _values} = prop ->
          append_iri(prop, v)

        _ ->
          new_iri(prop_name, v, alias)
      end

    struct(value, properties: Map.put(properties, prop_name, prop))
  end

  # append_iri appends an IRI value to the back of a list of the property "type"
  def append_iri(%{alias: alias_, values: values} = prop, %URI{} = v) when is_struct(prop) do
    struct(prop, values: values ++ [new_iri_iter(prop, v, alias_)])
  end

  def prepend_iris(value, _prop_name, []), do: value

  def prepend_iris(%{alias: alias_, properties: _properties} = value, prop_name, iris) do
    iters = Enum.map(iris, fn iri -> new_iri_iter(prop_name, iri, alias_) end)
    prepend_iters(value, prop_name, iters)
  end

  def prepend_iters(value, _prop_name, []), do: value

  def prepend_iters(%{alias: alias_, properties: properties} = value, prop_name, iters)
      when is_list(iters) do
    prop =
      case Map.get(properties, prop_name) do
        %{values: values} = prop ->
          struct(prop, values: iters ++ values)

        nil ->
          module = property_module(prop_name)
          struct(module, alias: alias_, values: iters)
      end

    struct(value, properties: Map.put(properties, prop_name, prop))
  end

  def remove_iris(value, _prop_name, []), do: value

  def remove_iris(%{alias: _alias_, properties: properties} = value, prop_name, iris) do
    iri_strs = Enum.map(iris, &URI.to_string(&1))

    case Map.get(properties, prop_name) do
      %{values: values} = prop ->
        remaining_values =
          Enum.filter(values, fn %{iri: iri} -> !Enum.member?(iri_strs, URI.to_string(iri)) end)

        case remaining_values do
          [] ->
            struct(value, properties: Map.delete(properties, prop_name))

          _ ->
            prop = struct(prop, values: values)
            struct(value, properties: Map.put(properties, prop_name, prop))
        end
    end
  end

  def new_iri(prop_name, %URI{} = v, alias_ \\ "") do
    module = property_module(prop_name)

    struct(module, alias: alias_, values: [new_iri_iter(prop_name, v, alias_)])
  end

  def new_iri_iter(prop_or_name, v, alias_ \\ "")

  def new_iri_iter(%{__struct__: module}, %URI{} = v, alias_) do
    iter_mod = iterator_module(module)
    struct(iter_mod, alias: alias_, iri: v)
  end

  def new_iri_iter(prop_module, %URI{} = v, alias_) when is_atom(prop_module) do
    iter_mod = iterator_module(prop_module)
    struct(iter_mod, alias: alias_, iri: v)
  end

  def new_iri_iter(prop_name, %URI{} = v, alias_) when is_binary(prop_name) do
    module = property_module(prop_name)
    iter_mod = iterator_module(module)
    struct(iter_mod, alias: alias_, iri: v)
  end

  def get_actor(%{properties: properties}) when is_map(properties) do
    case Map.get(properties, "actor") do
      %Fedi.ActivityStreams.Property.Actor{} = actor -> actor
      _ -> nil
    end
  end

  def get_actor_public_key(%{values: [%{member: %{properties: actor_props}} | _]}) do
    with %PublicKey{values: [%{member: %{properties: public_key_props}} | _]} <-
           Map.get(actor_props, "publicKey"),
         %PublicKeyPem{xsd_string_member: public_key} when is_binary(public_key) <-
           Map.get(public_key_props, "publicKeyPem") do
      public_key
    else
      _ -> nil
    end
  end

  def get_object(%{properties: properties}) when is_map(properties) do
    case Map.get(properties, "object") do
      %Fedi.ActivityStreams.Property.Object{} = object -> object
      _ -> nil
    end
  end

  def get_target(%{properties: properties}) when is_map(properties) do
    case Map.get(properties, "target") do
      %Fedi.ActivityStreams.Property.Target{} = target -> target
      _ -> nil
    end
  end

  def new_ordered_items() do
    %Fedi.ActivityStreams.Property.OrderedItems{alias: ""}
  end

  def get_ordered_items(%{properties: properties}) when is_map(properties) do
    with %Fedi.ActivityStreams.Property.OrderedItems{} = prop <-
           Map.get(properties, "orderedItems") do
      prop
    else
      _ ->
        nil
    end
  end

  def set_ordered_items(
        %{properties: properties} = ordered_collection_page,
        %Fedi.ActivityStreams.Property.OrderedItems{} = prop
      )
      when is_map(properties) do
    struct(ordered_collection_page, properties: Map.put(properties, "orderedItems", prop))
  end

  def prepend_to_ordered_items(
        %Fedi.ActivityStreams.Property.OrderedItems{alias: alias_, values: values} = prop,
        value
      )
      when is_list(values) do
    %Fedi.ActivityStreams.Property.OrderedItems{
      prop
      | values: [
          %Fedi.ActivityStreams.Property.OrderedItemsIterator{alias: alias_, member: value}
          | values
        ]
    }
  end

  @doc """
  Removes :authority, :userinfo, and :port after parsing a URI.
  Leaves :scheme, :host, :path, :query, and :fragment unchanged.
  """
  def to_uri(url) when is_binary(url) do
    %URI{} = uri = URI.parse(url)
    %URI{uri | authority: nil, userinfo: nil, port: nil}
  end

  @doc """
  Removes :authority, :userinfo, :port, :query, and :fragment from a URI.
  Leaves :scheme and :host unchanged.
  Sets :path if `path` is not nil, otherwise leaves it unchanged.
  """
  def base_uri(uri, path \\ nil)

  def base_uri(%URI{} = uri, path) when is_binary(path) do
    %URI{uri | path: path, authority: nil, fragment: nil, port: nil, query: nil, userinfo: nil}
  end

  def base_uri(%URI{} = uri, nil) do
    %URI{uri | authority: nil, fragment: nil, port: nil, query: nil, userinfo: nil}
  end

  def json_dumps(value) do
    with {:ok, m} <- Fedi.Streams.Serializer.serialize(value),
         {:ok, text} <- Jason.encode(m, pretty: true) do
      text
    else
      errs -> "#{inspect(errs)}"
    end
  end
end
