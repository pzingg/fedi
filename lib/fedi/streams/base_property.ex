defmodule Fedi.Streams.BaseProperty do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Utils

  @deserializers [
    :any_uri,
    :iri,
    :lang_string,
    :string,
    :boolean,
    :non_neg_integer,
    :float,
    :date_time,
    :duration,
    :bcp47,
    :rfc2045,
    :rfc5988,
    :object
  ]

  defmodule Pipeline do
    # Used for pipelines
    defstruct [
      :alias,
      :module,
      :member_types,
      :allowed_types,
      :prop_name,
      :input,
      :alias_map,
      :resolved_by,
      :result
    ]
  end

  def deserialize(namespace, module, member_types, prop_name, m, alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case Fedi.Streams.BaseProperty.get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        deserialize_with_alias(alias_, module, member_types, prop_name, i, alias_map)
    end
  end

  # TODO ONTOLOGY Limit to allowed_types (domain and range)?
  def deserialize_with_alias(alias_, module, member_types, prop_name, i, alias_map) do
    pipeline = %Pipeline{
      allowed_types: nil,
      alias: alias_,
      module: module,
      member_types: member_types,
      prop_name: prop_name,
      input: i,
      alias_map: alias_map
    }

    pipeline =
      Enum.reduce_while(@deserializers, pipeline, fn deser, acc ->
        with true <- Enum.member?(pipeline.member_types, deser),
             %Pipeline{result: result} = acc when not is_nil(result) <-
               deserialize_type(acc, deser) do
          {:halt, acc}
        else
          _ ->
            {:cont, acc}
        end
      end)

    case pipeline do
      %Pipeline{result: nil} ->
        {:ok, struct(pipeline.module, alias: pipeline.alias, unknown: pipeline.input)}

      %Pipeline{result: {:ok, value}} ->
        {:ok, value}

      %Pipeline{resolved_by: resolver, result: {:error, reason}} ->
        Logger.error("Pipeline #{resolver} returned error #{reason}")
        {:error, reason}

      %Pipeline{} = pipeline ->
        Logger.error("No result in #{inspect(pipeline)}")
        {:error, "Internal deserialization error"}
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :iri) when is_map(i) do
    # Logger.debug("#{inspect(i)} cannot be interpreted as a string for IRI")
    pipeline
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :iri) do
    case Fedi.Streams.Literal.String.maybe_to_string(i) do
      {:ok, s} ->
        uri = Utils.to_uri(s)

        # If error exists, don't error out -- skip this and treat as unknown string ([]byte) at worst
        # Also, if no scheme exists, don't treat it as a URL -- net/url is greedy
        if is_nil(uri.scheme) do
          Logger.debug("No scheme in #{inspect(i)} for IRI")
          pipeline
        else
          %Pipeline{
            pipeline
            | resolved_by: :iri,
              result: {:ok, struct(pipeline.module, alias: pipeline.alias, iri: uri)}
          }
        end

      {:error, reason} ->
        Logger.debug(":iri deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i, alias_map: alias_map} = pipeline, :object)
      when is_map(i) do
    (pipeline.allowed_types || Fedi.Streams.all_type_modules())
    |> Enum.reduce_while(:error, fn type_mod, acc ->
      with {:ok, v} when is_struct(v) <- apply(type_mod, :deserialize, [i, alias_map]) do
        {:halt, {:ok, struct(pipeline.module, alias: pipeline.alias, member: v)}}
      else
        _ ->
          {:cont, acc}
      end
    end)
    |> case do
      {:ok, value} ->
        %Pipeline{pipeline | resolved_by: :object, result: {:ok, value}}

      {:error, reason} ->
        Logger.debug(":object deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :object) do
    Logger.debug("#{inspect(i)} is not a map for object")
    pipeline
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :any_uri) do
    case Fedi.Streams.Literal.AnyURI.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :any_uri,
            result: {:ok, struct(pipeline.module, alias: pipeline.alias, xsd_any_uri_member: v)}
        }

      {:error, reason} ->
        Logger.debug(":any_uri deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :lang_string) do
    case Fedi.Streams.Literal.LangString.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :lang_string,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 rdf_lang_string_member: v
               )}
        }

      {:error, _reason} ->
        # This error occurs often for properties that usually have :string values.
        # Logger.debug(":lang_string deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :string) do
    case Fedi.Streams.Literal.String.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :string,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 xsd_string_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":string deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :boolean) do
    case Fedi.Streams.Literal.NonNegInteger.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :boolean,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 xsd_boolean_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":boolean deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :non_neg_integer) do
    case Fedi.Streams.Literal.NonNegInteger.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :non_neg_integer,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 xsd_non_neg_integer_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":non_neg_integer deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :float) do
    case Fedi.Streams.Literal.Float.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :float,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 xsd_float_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":float deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :date_time) do
    case Fedi.Streams.Literal.DateTime.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :date_time,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 xsd_date_time_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":date_time deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :duration) do
    case Fedi.Streams.Literal.Duration.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :duration,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 xsd_duration_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":duration deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :bcp47) do
    case Fedi.Streams.Literal.BCP47.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :bcp47,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 rfc_bcp47_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":bcp47 deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :rfc2045) do
    case Fedi.Streams.Literal.RFC2045.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :rfc2045,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 rfc_rfc2045_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":rfc2045 deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{input: i} = pipeline, :rfc5988) do
    case Fedi.Streams.Literal.RFC5988.deserialize(i) do
      {:ok, v} ->
        %Pipeline{
          pipeline
          | resolved_by: :rfc5988,
            result:
              {:ok,
               struct(pipeline.module,
                 alias: pipeline.alias,
                 rfc_rfc5988_member: v
               )}
        }

      {:error, reason} ->
        Logger.debug(":rfc5988 deserializer ERROR #{reason}")
        pipeline
    end
  end

  def deserialize_type(%Pipeline{} = pipeline, other) do
    Logger.error("Invalid type for deserializer #{other}")
    pipeline
  end

  def deserialize_values(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case get_values(m, prop_name, alias_) do
      [] ->
        {:ok, nil}

      values ->
        iterator_module =
          Module.split(module)
          |> List.update_at(-1, fn name -> name <> "Iterator" end)
          |> Module.concat()

        {mapped_values, unmapped_values} =
          values
          |> Enum.map(fn {i, prop_name, mapped_property?} ->
            case apply(iterator_module, :deserialize, [prop_name, mapped_property?, i, alias_map]) do
              {:ok, value} ->
                {value, mapped_property?}

              {:error, _reason} ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.split_with(fn {_, mapped_property?} -> mapped_property? end)

        mapped_values =
          mapped_values
          |> Enum.map(fn {value, _} -> value end)
          |> List.flatten()

        unmapped_values =
          unmapped_values
          |> Enum.map(fn {value, _} -> value end)
          |> List.flatten()

        value =
          if Enum.empty?(mapped_values) do
            struct(module, alias: alias_, values: unmapped_values)
          else
            struct(module,
              alias: alias_,
              mapped_values: mapped_values,
              values: unmapped_values
            )
          end

        {:ok, value}
    end
  end

  ##### Serialization

  # serialize converts this into an interface representation suitable for
  # marshalling into a text or binary format. Applications should not
  # need this function as most typical use cases serialize types
  # instead of individual properties. It is exposed for alternatives to
  # go-fed implementations to use.
  def serialize_values(%{values: values, mapped_values: mapped_values})
      when is_list(values) and is_list(mapped_values) do
    unmapped = do_serialize_values(values)
    mapped = do_serialize_values(mapped_values)

    case {unmapped, mapped} do
      {{:error, reason}, _} ->
        {:error, reason}

      {_, {:error, reason}} ->
        {:error, reason}

      {{:ok, unmapped_v}, {:ok, mapped_v}} ->
        {:ok, %Fedi.Streams.MappedNameProp{unmapped: unmapped_v, mapped: mapped_v}}
    end
  end

  def serialize_values(%{values: values}) when is_list(values) do
    do_serialize_values(values)
  end

  def serialize_values(prop) do
    {:error, "#{inspect(prop)} does not have values or mapped_values lists"}
  end

  def do_serialize_values(values) when is_list(values) do
    result =
      Enum.reduce_while(values, [], fn it, acc ->
        case serialize(it) do
          {:error, reason} -> {:halt, {:error, reason}}
          {:ok, b} -> {:cont, [b | acc]}
        end
      end)

    case result do
      {:error, reason} -> {:error, reason}
      # Shortcut: if serializing one value, don't return an array -- pretty sure other Fediverse software would choke on a "type" value with array, for example.
      [] -> {:ok, nil}
      [single_value] -> {:ok, single_value}
      value_list when is_list(value_list) -> {:ok, Enum.reverse(value_list)}
    end
  end

  def serialize(%{values: values} = prop) when is_list(values) do
    serialize_values(prop)
  end

  def serialize(%{member: member}) when is_struct(member) do
    apply(member.__struct__, :serialize, [member])
  end

  def serialize(%{rdf_lang_string_member: v}) when is_map(v) do
    Fedi.Streams.Literal.LangString.serialize(v)
  end

  def serialize(%{xsd_date_time_member: %DateTime{} = v}) do
    Fedi.Streams.Literal.DateTime.serialize(v)
  end

  def serialize(%{xsd_duration_member: %Timex.Duration{} = v}) do
    Fedi.Streams.Literal.Duration.serialize(v)
  end

  def serialize(%{xsd_non_neg_integer_member: v}) when is_integer(v) do
    Fedi.Streams.Literal.NonNegInteger.serialize(v)
  end

  def serialize(%{xsd_float_member: v}) when is_float(v) do
    Fedi.Streams.Literal.Float.serialize(v)
  end

  def serialize(%{xsd_string_member: str}) when is_binary(str) do
    {:ok, str}
  end

  def serialize(%{xsd_any_uri_member: %URI{} = uri}) do
    Fedi.Streams.Literal.AnyURI.serialize(uri)
  end

  def serialize(%{iri: %URI{} = iri}) do
    {:ok, URI.to_string(iri)}
  end

  def serialize(%{unknown: unknown}) do
    {:ok, unknown}
  end

  def serialize(nil), do: {:ok, ""}

  def serialize(other) do
    Logger.error("Attempted to serialize unknown type #{inspect(other)}")
    {:error, "Attempted to serialize unknown type #{inspect(other)}"}
  end

  #### Getters

  # get returns the value of this property
  def get(%{member: value}) when is_struct(value), do: value
  def get(_), do: nil

  # get_iri returns the IRI of this property. When is_iri returns false,
  # get_iri will return any arbitrary value.
  def get_iri(%{iri: %URI{} = v}), do: v
  def get_iri(_), do: nil

  # get_xsd_any_uri returns the value of this property. When IsXMLSchemaAnyURI
  # returns false, get_xsd_any_uri will return an arbitrary value.
  def get_xsd_any_uri(%{xsd_any_uri_member: %URI{} = v}), do: v
  def get_xsd_any_uri(_), do: nil

  # get_xsd_string returns the value of this property. When is_xsd_string
  # returns false, get_xsd_string will return an arbitrary value.
  def get_xsd_string(%{xsd_string_member: v}) when is_binary(v), do: v
  def get_xsd_string(_), do: nil

  # json_ld_context returns the JSONLD URIs required in the context string
  # for this property and the specific values that are set. The value
  # in the map is the alias used to import the property's value or
  # values.
  # TODO IMPL
  def json_ld_context(_prop) do
    %{}
  end

  #### Queries

  # is_iri returns true if this property is an IRI.
  def is_iri(%{iri: %URI{}}), do: true
  def is_iri(_), do: false

  # is_xsd_any_uri returns true if this property is set and not an IRI.
  def is_xsd_any_uri(%{xsd_any_uri_member: %URI{}}), do: true
  def is_xsd_any_uri(_), do: false

  # is_xsd_string returns true if this property has a type of "string". When
  # true, use the get_xsd_string and set_xsd_string methods to access
  # and set this property.
  def is_xsd_string(%{xsd_string_member: v}) when is_binary(v), do: true
  def is_xsd_string(_), do: false

  #### Setters

  # set sets the value of this property. Calling is_xsd_any_uri
  # afterwards will return true.
  def set(%{__struct__: module, member: _old_value} = prop, v) when is_struct(v) do
    apply(module, :clear, [prop])
    |> struct(member: v)
  end

  # set_iri sets the value of this property. Calling is_iri afterwards will
  # return true.
  def set_iri(%{__struct__: module, iri: _old_value} = prop, %URI{} = v) do
    apply(module, :clear, [prop])
    |> struct(iri: v)
  end

  # set_xsd_any_uri sets a new IRI value.
  def set_xsd_any_uri(
        %{__struct__: module, xsd_any_uri_member: _old_value} = prop,
        %URI{} = v
      ) do
    apply(module, :clear, [prop])
    |> struct(xsd_any_uri_member: v)
  end

  # set_xsd_string sets a new IRI value.
  def set_xsd_string(
        %{
          __struct__: module,
          xsd_string_member: _old_string
        } = prop,
        v
      )
      when is_binary(v) do
    apply(module, :clear, [prop])
    |> struct(xsd_string_member: v)
  end

  # kind_index computes an arbitrary value for indexing this kind of value.
  # This is a leaky API detail only for folks looking to replace the
  # go-fed implementation. Applications should not use this method.
  def kind_index(prop, types \\ nil)

  def kind_index(%{member: value} = prop, types) when is_struct(value) do
    (types || Fedi.Streams.all_type_modules())
    |> Enum.with_index()
    |> Enum.find(fn {{_prop_name, prop_mod}, _idx} -> value == prop_mod end)
    |> case do
      {{_prop_name, _prop_mod}, idx} -> idx + 1
      nil -> base_kind_index(prop)
    end
  end

  def kind_index(prop, _), do: base_kind_index(prop)

  def base_kind_index(%{xsd_any_uri_member: %URI{}}), do: 0
  def base_kind_index(%{iri: %URI{}}), do: -2
  def base_kind_index(_), do: -1

  # less_than compares two instances of this property with an arbitrary but
  # stable comparison. Applications should not use this because it is
  # only meant to help alternative implementations to go-fed to be able
  # to normalize nonfunctional properties.
  def less_than(%{} = prop, %{} = o) do
    idx1 = kind_index(prop)
    idx2 = kind_index(o)

    cond do
      idx1 < idx2 ->
        true

      idx2 < idx1 ->
        false

      idx1 >= 0 ->
        val1 = get(prop)
        val2 = get(o)
        apply(val1.__struct__, :less_than, [val1, val2])

      true ->
        nil
    end
    |> case do
      is_less_than when is_boolean(is_less_than) ->
        is_less_than

      _ ->
        iri1 = get_iri(prop)
        iri2 = get_iri(o)

        case {iri1, iri2} do
          {nil, nil} -> false
          {nil, _iri} -> true
          {_iri, nil} -> false
          _ -> to_string(iri1) < to_string(iri2)
        end
    end
  end

  #### Utility functions

  def get_prop(m, prop_names, alias_) when is_binary(alias_) do
    prop_names
    |> List.wrap()
    |> Enum.reduce_while(nil, fn prop_name, _acc ->
      prop_name =
        case alias_ do
          "" ->
            prop_name

          _ ->
            alias_ <> ":" <> prop_name
        end

      case Map.get(m, prop_name) do
        nil ->
          {:cont, nil}

        val ->
          # TODO ONTOLOGY
          mapped_property? = String.ends_with?(prop_name, "Map")
          {:halt, {val, prop_name, mapped_property?}}
      end
    end)
  end

  def get_values(m, prop_names, alias_) when is_binary(alias_) do
    prop_names
    |> List.wrap()
    |> Enum.reduce([], fn prop_name, acc ->
      prop_name =
        case alias_ do
          "" ->
            prop_name

          _ ->
            alias_ <> ":" <> prop_name
        end

      case Map.get(m, prop_name) do
        nil ->
          acc

        val ->
          # TODO ONTOLOGY
          mapped_property? = String.ends_with?(prop_name, "Map")
          [{val, prop_name, mapped_property?} | acc]
      end
    end)
  end

  def name(prop_names, alias_, is_map \\ false) do
    prop_name =
      prop_names
      |> List.wrap()
      |> List.first()

    map_suffix = if is_map, do: "Map", else: ""

    case alias_ do
      "" -> prop_name <> map_suffix
      _ -> alias_ <> ":" <> prop_name <> map_suffix
    end
  end
end
