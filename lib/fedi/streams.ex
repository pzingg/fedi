defmodule Fedi.Streams do
  @moduledoc """
  Documentation for `Fedi.Streams`.
  """

  def get_alias(alias_map, :json_ld) when is_map(alias_map), do: ""

  def get_alias(alias_map, :activity_streams) when is_map(alias_map) do
    Map.get(alias_map, "https://www.w3.org/ns/activitystreams", "")
  end

  def get_alias(alias_map, :toot) when is_map(alias_map) do
    Map.get(alias_map, "http://joinmastodon.org/ns", "")
  end

  def get_alias(alias_map, :w3_id_security_v1) when is_map(alias_map) do
    Map.get(alias_map, "https://w3id.org/security/v1", "")
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
