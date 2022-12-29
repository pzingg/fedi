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
      %Fedi.JSON.LD.Property.Type{properties: types} ->
        if types == [] do
          nil
        else
          types
        end

      _ ->
        nil
    end
  end

  def get_json_ld_type(_), do: nil

  @doc """
  get_id will attempt to find the 'id' property or, if it happens to be a
  Link or derived from Link type, the 'href' property instead.

  Returns an error if the id is not set and either the 'href' property is not
  valid on this type, or it is also not set.
  """
  def get_id(%{properties: properties} = as_value) do
    case get_json_ld_id(as_value) do
      %URI{} = id ->
        id

      nil ->
        case Map.get(properties, "href") do
          %Fedi.ActivityStreams.Property.Href{xml_schema_any_uri_member: %URI{} = id} ->
            id

          _ ->
            nil
        end
    end
  end

  def get_id_or_iri(%{properties: properties} = as_value, prop_name) do
    case get_id(as_value) do
      %URI{} = id ->
        id

      _ ->
        case Map.get(properties, prop_name) do
          %{iri: %URI{} = iri} -> iri
          _ -> nil
        end
    end
  end

  def get_ordered_items(%{properties: properties}) do
    case Map.get(properties, "orderedItems") do
      %Fedi.ActivityStreams.Property.OrderedItems{} = items ->
        items

      _ ->
        nil
    end
  end
end
