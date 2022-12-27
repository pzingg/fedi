defmodule Fedi.Streams do
  @moduledoc """
  Documentation for `Fedi.Streams`.
  """

  def get_alias(alias_map, :activity_streams) do
    Map.get(alias_map, "https://www.w3.org/ns/activitystreams", "")
  end

  def get_alias(alias_map, :mastodon) do
    Map.get(alias_map, "http://joinmastodon.org/ns", "")
  end

  def get_alias(alias_map, :security_v1) do
    Map.get(alias_map, "https://w3id.org/security/v1", "")
  end

  def all_type_modules() do
    Fedi.ActivityStreams.type_modules() ++
      Fedi.Mastodon.type_modules() ++
      Fedi.SecurityV1.type_modules()
  end

  def type_modules(:activity_streams) do
    Fedi.ActivityStreams.type_modules()
  end

  def properties(:activity_streams) do
    Fedi.JSON.LD.properties() ++
      Fedi.ActivityStreams.properties()
  end

  def properties(:mastodon) do
    Fedi.JSON.LD.properties() ++
      Fedi.ActivityStreams.properties() ++
      Fedi.Mastodon.properties()
  end

  def properties(:security_v1) do
    Fedi.JSON.LD.properties() ++
      Fedi.ActivityStreams.properties()
  end
end
