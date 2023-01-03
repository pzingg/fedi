defmodule Fedi.Streams.Utils do
  @moduledoc false

  require Logger

  def iterator_module(module) do
    Module.split(module)
    |> List.update_at(-1, fn name -> name <> "Iterator" end)
    |> Module.concat()
  end

  def base_module(module) do
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
  #       "id" => %Fedi.JSON.LD.Property.Id{xsd_any_uri_member: %URI{...}},
  #     }
  #   }
  # }
  def get_json_ld_id(%{member: member}) when is_struct(member) do
    # A property with a type member
    get_json_ld_id(member)
  end

  def get_json_ld_id(%{properties: properties}) do
    # A type with properties
    case Map.get(properties, "id") do
      %Fedi.JSON.LD.Property.Id{xsd_any_uri_member: %URI{} = id} ->
        id

      _ ->
        nil
    end
  end

  def get_json_ld_id(_), do: nil

  def get_json_ld_type(%{member: member}) when is_struct(member) do
    # A property with a type member
    get_json_ld_type(member)
  end

  def get_json_ld_type(%{properties: properties}) do
    # A type with properties
    case Map.get(properties, "type") do
      %Fedi.JSON.LD.Property.Type{values: types} ->
        case types do
          [] -> nil
          [type] -> type
          _ -> types
        end

      _ ->
        nil
    end
  end

  def get_json_ld_type(_), do: nil

  @actor_types ["Application", "Group", "Organization", "Person", "Service"]
  @link_types ["Link", "Mention"]

  # TODO generate from spec
  def has_inbox?(%{member: member}) do
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

  # TODO generate from spec
  def has_href?(%{member: member}) do
    has_href?(member)
  end

  def has_href?(%{properties: _} = value) do
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

  def get_href(%{member: member}) do
    get_href(member)
  end

  def get_href(%{properties: properties}) do
    case Map.get(properties, "href") do
      %Fedi.ActivityStreams.Property.Href{xsd_any_uri_member: %URI{} = href} ->
        href

      _ ->
        nil
    end
  end

  @doc """
  get_id will attempt to find the 'id' property or, if it happens to be a
  Link or derived from Link type, the 'href' property instead.

  Returns an error if the id is not set and either the 'href' property is not
  valid on this type, or it is also not set.
  """
  def get_id!(prop_or_type) when is_struct(prop_or_type) do
    case get_id(prop_or_type) do
      %URI{} = id -> id
      _ -> raise "No id or href set on #{alias_module(prop_or_type.__struct__)}"
    end
  end

  def get_id(prop_or_type) when is_struct(prop_or_type) do
    case get_json_ld_id(prop_or_type) do
      %URI{} = id ->
        id

      nil ->
        if has_href?(prop_or_type) do
          get_href(prop_or_type)
        else
          nil
        end
    end
  end

  def get_iri(%{iri: %URI{} = iri}), do: iri
  def get_iri(_), do: nil

  def get_id_or_iri!(prop_or_type) when is_struct(prop_or_type) do
    case get_id_or_iri(prop_or_type) do
      %URI{} = id -> id
      _ -> raise "No id or IRI set on property #{alias_module(prop_or_type.__struct__)}"
    end
  end

  def get_id_or_iri(prop_or_type) when is_struct(prop_or_type) do
    case get_id(prop_or_type) do
      %URI{} = id ->
        id

      _ ->
        get_iri(prop_or_type)
    end
  end

  def get_iri_or_id!(prop_or_type) when is_struct(prop_or_type) do
    case get_iri_or_id(prop_or_type) do
      %URI{} = id -> id
      _ -> raise "No IRI or id set on property #{alias_module(prop_or_type.__struct__)}"
    end
  end

  def get_iri_or_id(prop_or_type) when is_struct(prop_or_type) do
    case get_iri(prop_or_type) do
      %URI{} = iri ->
        iri

      _ ->
        get_id(prop_or_type)
    end
  end

  @doc """
  Extracts the 'inbox' IRIs from actor types.
  """
  def get_inboxes(values) when is_list(values) do
    Enum.map(values, &get_inbox(&1))
    |> Enum.filter(fn i -> !is_nil(i) end)
  end

  @doc """
  Extracts the 'inbox' IRI from an actor property or type.
  """
  def get_inbox(%{member: member}) do
    get_inbox(member)
  end

  def get_inbox(%{properties: properties} = value) do
    if has_inbox?(value) do
      case Map.get(properties, "inbox") do
        %Fedi.ActivityStreams.Property.Inbox{} = inbox ->
          get_iri_or_id(inbox)

        _ ->
          nil
      end
    else
      nil
    end
  end

  def get_actors(%{properties: properties}) do
    case Map.get(properties, "actor") do
      %Fedi.ActivityStreams.Property.Actor{values: values} ->
        values

      _ ->
        nil
    end
  end

  def new_ordered_items() do
    %Fedi.ActivityStreams.Property.OrderedItems{alias: ""}
  end

  def get_ordered_items(%{properties: properties}) do
    # Logger.error("get_ordered_items properties: #{inspect(properties)}")

    case Map.get(properties, "orderedItems") do
      %Fedi.ActivityStreams.Property.OrderedItems{} = value ->
        value

      _ ->
        nil
    end
  end

  def set_ordered_items(
        %{properties: properties} = ordered_collection_page,
        %Fedi.ActivityStreams.Property.OrderedItems{} = value
      ) do
    struct(ordered_collection_page, properties: Map.put(properties, "orderedItems", value))
  end
end
