defmodule Fedi.Streams do
  @moduledoc """
  Documentation for `Fedi.Streams`.
  """

  def get_alias(context, namespace) do
    {_vocab_module, alias_prefix} = Map.fetch!(context, namespace)
    alias_prefix
  end

  def all_type_modules() do
    Fedi.ActivityStreams.type_modules() ++
      Fedi.Toot.type_modules() ++
      Fedi.W3IDSecurityV1.type_modules()
  end

  def type_modules(:activity_streams) do
    Fedi.ActivityStreams.type_modules()
  end

  def properties(:activity_streams) do
    Fedi.JSONLD.properties() ++
      Fedi.ActivityStreams.properties()
  end

  def properties(:toot) do
    Fedi.JSONLD.properties() ++
      Fedi.ActivityStreams.properties() ++
      Fedi.Toot.properties()
  end

  def properties(:w3_id_security_v1) do
    Fedi.JSONLD.properties() ++
      Fedi.ActivityStreams.properties()
  end

  def has_map_property?(_namespace, prop_name) do
    Fedi.ActivityStreams.has_map_property?(prop_name)
  end
end
