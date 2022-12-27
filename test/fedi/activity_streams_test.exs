defmodule Fedi.StreamsTest do
  use ExUnit.Case
  doctest Fedi.Streams

  require Logger

  describe "examples" do
    test "example 9" do
      source = """
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "summary": "Sally accepted an invitation to a party",
        "type": "Accept",
        "actor": {
          "type": "Person",
          "name": "Sally"
        },
        "object": {
          "type": "Invite",
          "actor": "http://john.example.org",
          "object": {
            "type": "Event",
            "name": "Going-Away Party for Jim"
          }
        }
      }
      """

      assert {:ok, accept} = Fedi.Streams.JsonResolver.resolve(source)
      assert accept.__struct__ == Fedi.ActivityStreams.Type.Accept
      assert accept.properties["actor"].__struct__ == Fedi.ActivityStreams.Property.Actor
      assert accept.properties["object"].__struct__ == Fedi.ActivityStreams.Property.Object
      assert accept.properties["summary"].__struct__ == Fedi.ActivityStreams.Property.Summary
      assert accept.properties["type"].__struct__ == Fedi.JSON.LD.Property.Type
    end

    test "example 9 with langString" do
      source = """
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "summary": "Sally accepted an invitation to a party",
        "type": "Accept",
        "actor": {
          "type": "Person",
          "name": "Sally"
        },
        "object": {
          "type": "Invite",
          "actor": "http://john.example.org",
          "object": {
            "type": "Event",
            "nameMap": {
              "en": "Going-Away Party for Jim",
              "fr": "Fête de départ pour Jim"
            }
          }
        }
      }
      """

      assert {:ok, accept} = Fedi.Streams.JsonResolver.resolve(source)
      assert accept.__struct__ == Fedi.ActivityStreams.Type.Accept
      assert accept.properties["actor"].__struct__ == Fedi.ActivityStreams.Property.Actor
      assert accept.properties["object"].__struct__ == Fedi.ActivityStreams.Property.Object
      assert accept.properties["summary"].__struct__ == Fedi.ActivityStreams.Property.Summary
      assert accept.properties["type"].__struct__ == Fedi.JSON.LD.Property.Type

      invite_object = accept.properties["object"]
      invite_prop = List.first(invite_object.properties)
      assert invite_prop.member.__struct__ == Fedi.ActivityStreams.Type.Invite

      event_object = invite_prop.member.properties["object"]
      event_prop = List.first(event_object.properties)
      assert event_prop.member.__struct__ == Fedi.ActivityStreams.Type.Event

      name_object = event_prop.member.properties["name"]
      name_prop = List.first(name_object.properties)
      assert name_prop.__struct__ == Fedi.ActivityStreams.Property.NameIterator
      assert is_map(name_prop.rdf_lang_string_member)
      assert name_prop.rdf_lang_string_member["en"] == "Going-Away Party for Jim"
      assert name_prop.unknown == nil

      assert Fedi.ActivityStreams.Property.NameIterator.name(name_prop) == "nameMap"
    end
  end
end
