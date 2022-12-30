defmodule Fedi.Streams.Utils do
  @moduledoc false

  def get_json_ld_id(%{properties: properties}) do
    case Map.get(properties, "id") do
      %Fedi.JSON.LD.Property.Id{xml_schema_any_uri_member: %URI{} = id} ->
        id

      _ ->
        nil
    end
  end

  def get_json_ld_id(_), do: nil

  def get_json_ld_type(%{properties: properties}) do
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
  def type_has_inbox?(value) do
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
  def type_has_href?(value) do
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

  @doc """
  get_id will attempt to find the 'id' property or, if it happens to be a
  Link or derived from Link type, the 'href' property instead.

  Returns an error if the id is not set and either the 'href' property is not
  valid on this type, or it is also not set.
  """
  def get_id!(as_value) do
    case get_id(as_value) do
      %URI{} = id -> id
      _ -> raise "No id or href set on type"
    end
  end

  def get_id(%{properties: properties} = as_value) do
    case get_json_ld_id(as_value) do
      %URI{} = id ->
        id

      nil ->
        if type_has_href?(as_value) do
          case Map.get(properties, "href") do
            %Fedi.ActivityStreams.Property.Href{xml_schema_any_uri_member: %URI{} = id} ->
              id

            _ ->
              nil
          end
        else
          nil
        end
    end
  end

  def get_iri(%{properties: properties}, prop_name) do
    case Map.get(properties, prop_name) do
      %{iri: %URI{} = iri} -> iri
      _ -> nil
    end
  end

  def get_id_or_iri!(as_value, prop_name) do
    case get_id_or_iri(as_value, prop_name) do
      %URI{} = id -> id
      _ -> raise "No id or IRI set on type"
    end
  end

  def get_id_or_iri(%{properties: _} = as_value, prop_name) do
    case get_id(as_value) do
      %URI{} = id ->
        id

      _ ->
        get_iri(as_value, prop_name)
    end
  end

  def get_iri_or_id!(as_value, prop_name) do
    case get_iri_or_id(as_value, prop_name) do
      %URI{} = id -> id
      _ -> raise "No IRI or id set on type"
    end
  end

  def get_iri_or_id(%{properties: _} = as_value, prop_name) do
    case get_iri(as_value, prop_name) do
      %URI{} = iri ->
        iri

      _ ->
        get_id(as_value)
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
  Extracts the 'inbox' IRI from an actor type.
  """
  def get_inbox(as_value) do
    if type_has_inbox?(as_value) do
      Fedi.Streams.Utils.get_id_or_iri(as_value, "inbox")
    else
      nil
    end
  end

  def get_actors(%{properties: properties}) do
    case Map.get(properties, "actor") do
      %Fedi.ActivityStreams.Property.Actor{} = value ->
        value

      _ ->
        nil
    end
  end

  def new_ordered_items() do
    %Fedi.ActivityStreams.Property.OrderedItems{alias: ""}
  end

  def get_ordered_items(%{properties: properties}) do
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
