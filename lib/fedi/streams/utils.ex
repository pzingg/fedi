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
  @document_types ["Audio", "Document", "Page", "Image", "Video"]
  @post_types ["Article", "Note"]
  @actor_types ["Application", "Group", "Organization", "Person", "Service"]
  @link_types ["Link", "Mention"]

  ### Errors

  @doc """
  Indicates that the activity needs its 'actor' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_actor_required(data \\ []) do
    Error.new(:actor_required, "Actor property required on the provided activity", false, data)
  end

  @doc """
  Indicates that the activity needs its 'object' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_object_required(data \\ []) do
    Error.new(:object_required, "Object property required on the provided activity", false, data)
  end

  @doc """
  Indicates that the activity needs its 'target' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_target_required(data \\ []) do
    Error.new(:target_required, "Target property required on the provided activity", false, data)
  end

  @doc """
  Indicates that the activity needs its 'id' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_id_required(data \\ []) do
    Error.new(:id_required, "Id property required on the provided Activity", false, data)
  end

  @doc """
  Indicates that the activity needs its 'type' property
  set. Can be returned by `Actor.handle_post_inbox/2` or
  `Actor.handle_post_outbox/2` so a Bad Request response is set.
  """
  def err_type_required(data \\ []) do
    Error.new(:id_required, "Id property required on the provided Activity", false, data)
  end

  @doc """
  Indicates that an ActivityStreams value has a type that is not
  handled by the JSONResolver.
  """
  def err_unhandled_type(message, data \\ []) do
    Error.new(:unhandled_type, message, false, data)
  end

  @doc """
  Indicates that an exception was raised during serialization.
  """
  def err_serialization(message, data \\ []) do
    Error.new(:serialization, message, true, data)
  end

  def capitalize(str) do
    {head, rest} = String.split_at(str, 1)
    String.upcase(head) <> rest
  end

  # TODO ONTOLOGY
  def property_module(prop_name) do
    Module.concat(["Fedi", "ActivityStreams", "Property", capitalize(prop_name)])
  end

  # On an iterating property
  def iterator_module(%{__struct__: module, values: _}), do: iterator_module(module)

  def iterator_module(module) when is_atom(module) do
    Module.split(module)
    |> List.update_at(-1, fn name -> name <> "Iterator" end)
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
  # For iterating property
  def get_json_ld_id(%{values: [prop | _]}) do
    get_json_ld_id(prop)
  end

  # For functional property
  def get_json_ld_id(%{member: member}) when is_struct(member) do
    # A property with a type member
    get_json_ld_id(member)
  end

  # For type
  def get_json_ld_id(%{properties: properties}) when is_map(properties) do
    # A type with properties
    case Map.get(properties, "id") do
      %Fedi.JSONLD.Property.Id{xsd_any_uri_member: %URI{} = id} ->
        id

      _ ->
        nil
    end
  end

  def get_json_ld_id(_), do: nil

  def set_json_ld_id(%{member: member} = value, %URI{} = id) when is_struct(member) do
    case set_json_ld_id(member, id) do
      {:ok, member_with_id} -> {:ok, struct(value, member: member_with_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_json_ld_id(%{properties: properties} = prop, %URI{} = id) when is_map(properties) do
    {:ok, struct(prop, properties: Map.put(properties, "id", Fedi.JSONLD.Property.Id.new_id(id)))}
  end

  def set_json_ld_id(_, %URI{} = _id) do
    {:error, "Can only set JSONLDID on a value or functional property"}
  end

  def get_json_ld_type(%{member: member}) when is_struct(member) do
    # A property with a type member
    get_json_ld_type(member)
  end

  def get_json_ld_type(%{properties: properties}) when is_map(properties) do
    # A type with properties
    with %Fedi.JSONLD.Property.Type{
           values: [
             %Fedi.JSONLD.Property.TypeIterator{
               has_string_member?: true,
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

  def get_json_ld_type(_), do: nil

  def set_json_ld_type(%{member: member} = value, type) when is_struct(member) do
    case set_json_ld_type(member, type) do
      {:ok, member_with_type} -> {:ok, struct(value, member: member_with_type)}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_json_ld_type(%{properties: properties} = prop, type) when is_map(properties) do
    {:ok,
     struct(prop,
       properties: Map.put(properties, "type", Fedi.JSONLD.Property.Type.new_type(type))
     )}
  end

  def set_json_ld_type(_, %URI{} = _id) do
    {:error, "Can only set JSONLDType on a value or functional property"}
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
      Enum.member?(@activity_types, type_name) -> :activities
      Enum.member?(@document_types, type_name) -> :documents
      Enum.member?(@post_types, type_name) -> :posts
      Enum.member?(@actor_types, type_name) -> :actors
      Enum.member?(@link_types, type_name) -> :links
      true -> :objects
    end
  end

  # TODO ONTOLOGY
  def has_inbox?(%{member: member}) when is_struct(member) do
    has_inbox?(member)
  end

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
  def has_href?(%{member: member}) when is_struct(member) do
    has_href?(member)
  end

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

  def get_actor_or_attributed_to_iri(%{
        properties: %{
          "attributedTo" => %Fedi.ActivityStreams.Property.AttributedTo{
            values: [
              %Fedi.ActivityStreams.Property.AttributedToIterator{
                iri: %URI{} = iri
              }
              | _
            ]
          }
        }
      }) do
    iri
  end

  def get_actor_or_attributed_to_iri(%{
        properties: %{
          "actor" => %Fedi.ActivityStreams.Property.Actor{
            values: [
              %Fedi.ActivityStreams.Property.ActorIterator{
                iri: %URI{} = iri
              }
              | _
            ]
          }
        }
      }) do
    iri
  end

  def get_actor_or_attributed_to_iri(_), do: nil

  # For iterating property
  def get_iri(%{values: [%{iri: %URI{} = iri} | _]}), do: iri

  # For functional property
  def get_iri(%{iri: %URI{} = iri}), do: iri

  def get_iri(_), do: nil

  def set_iri(%{properties: properties} = value, prop_name, nil) do
    struct(value, properties: Map.delete(properties, prop_name))
  end

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

  def append_iris(%{alias: alias_, properties: _properties} = value, prop_name, iris) do
    iters = Enum.map(iris, fn iri -> new_iri_iter(prop_name, iri, alias_) end)
    append_iters(value, prop_name, iters)
  end

  def append_iters(value, _prop_name, []), do: value

  def append_iters(%{alias: alias_, properties: properties} = value, prop_name, iters)
      when is_list(iters) do
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

  def new_iri_iter(prop_name, %URI{} = v, alias_) do
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

  def json_dumps(value) do
    with {:ok, m} <- Fedi.Streams.Serializer.serialize(value),
         {:ok, text} <- Jason.encode(m, pretty: true) do
      text
    else
      errs -> "#{inspect(errs)}"
    end
  end
end
