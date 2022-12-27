defmodule Fedi.JSON.LD.Property.Id do
  @moduledoc """
  Provides the globally unique identifier for JSON-LD entities.
  """

  defstruct [
    :xml_schema_any_uri_member,
    :unknown,
    :alias
  ]

  @type t() :: %__MODULE__{
          xml_schema_any_uri_member: URI.t() | nil,
          unknown: term(),
          alias: String.t()
        }

  # deserialize creates an "id" property from an interface representation
  # that has been unmarshalled from a text or binary format.
  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    alias = ""
    # Use alias both to find the property, and set within the property.
    prop_name =
      if String.length(alias) > 0 do
        alias <> ":id"
      else
        "id"
      end

    case Map.get(m, prop_name) do
      nil ->
        {:ok, nil}

      i ->
        case Fedi.Streams.Literal.AnyURI.deserialize(i) do
          {:ok, v} ->
            {:ok,
             %__MODULE__{
               alias: alias,
               xml_schema_any_uri_member: v
             }}

          {:error, _reason} ->
            {:ok,
             %__MODULE__{
               alias: alias,
               unknown: i
             }}
        end
    end
  end

  # new creates a new id property.
  def new() do
    %__MODULE__{alias: ""}
  end

  # clear ensures no value of this property is set. Calling
  # is_xml_schema_any_uri afterwards will return false.
  def clear(%__MODULE__{} = prop) do
    %__MODULE__{prop | unknown: nil, xml_schema_any_uri_member: nil}
  end

  # get returns the value of this property. When is_xml_schema_any_uri returns
  # false, get will return any arbitrary value.
  def get(%__MODULE__{} = prop) do
    prop.xml_schema_any_uri_member
  end

  # get_iri returns the IRI of this property. When is_iri returns false,
  # get_iri will return any arbitrary value.
  def get_iri(%__MODULE__{} = prop) do
    prop.xml_schema_any_uri_member
  end

  # has_any returns true if the value or IRI is set.
  def has_any(%__MODULE__{} = prop) do
    is_xml_schema_any_uri(prop)
  end

  # is_iri returns true if this property is an IRI.
  def is_iri(%__MODULE__{} = prop) do
    !is_nil(prop.xml_schema_any_uri_member)
  end

  # is_xml_schema_any_uri returns true if this property is set and not an IRI.
  def is_xml_schema_any_uri(%__MODULE__{} = prop) do
    !is_nil(prop.xml_schema_any_uri_member)
  end

  # json_ld_context returns the JSONLD URIs required in the context string
  # for this property and the specific values that are set. The value
  # in the map is the alias used to import the property's value or
  # values.
  def json_ld_context(%__MODULE__{} = _prop) do
    %{}
  end

  # kind_index computes an arbitrary value for indexing this kind of value.
  # This is a leaky API detail only for folks looking to replace the
  # go-fed implementation. Applications should not use this method.
  def kind_index(%__MODULE__{} = prop) do
    cond do
      is_xml_schema_any_uri(prop) -> 0
      is_iri(prop) -> -2
      true -> -1
    end
  end

  # less_than compares two instances of this property with an arbitrary but
  # stable comparison. Applications should not use this because it is
  # only meant to help alternative implementations to go-fed to be able
  # to normalize nonfunctional properties.

  def less_than(%__MODULE__{} = prop, %__MODULE__{} = o) do
    cond do
      # IRIs are always less than other values, none, or unknowns
      is_iri(prop) -> true
      # This other, none, or unknown value is always greater than IRIs
      is_iri(o) -> false
      # less_than comparison for the single value or unknown value.
      # Both are unknowns.
      !is_xml_schema_any_uri(prop) && !is_xml_schema_any_uri(o) -> false
      # Values are always greater than unknown values.
      is_xml_schema_any_uri(prop) && !is_xml_schema_any_uri(o) -> false
      # Unknowns are always less than known values.
      !is_xml_schema_any_uri(prop) && is_xml_schema_any_uri(o) -> true
      # Actual comparison.
      true -> Fedi.Streams.Literal.AnyURI.less(get(prop), get(o))
    end
  end

  # name returns the name of this property: "id".
  def name(%__MODULE__{alias: alias}) do
    if String.length(alias) > 0 do
      alias <> ":id"
    else
      "id"
    end
  end

  # serialize converts this into an interface representation suitable for
  # marshalling into a text or binary format. Applications should not
  # need this function as most typical use cases serialize types
  # instead of individual properties. It is exposed for alternatives to
  # go-fed implementations to use.
  def serialize(%__MODULE__{} = prop) do
    if is_xml_schema_any_uri(prop) do
      get(prop) |> Fedi.Streams.Literal.AnyURI.serialize()
    else
      {:ok, prop.unknown}
    end
  end

  # set sets the value of this property. Calling is_xml_schema_any_uri
  # afterwards will return true.
  def set(%__MODULE__{} = prop, %URI{} = v) do
    prop = clear(prop)
    %__MODULE__{prop | xml_schema_any_uri_member: v}
  end

  # set_iri sets the value of this property. Calling is_iri afterwards will
  # return true.
  def set_iri(%__MODULE__{} = prop, %URI{} = v) do
    prop
    |> clear()
    |> set(v)
  end
end
