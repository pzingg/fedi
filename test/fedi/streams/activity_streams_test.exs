defmodule Fedi.StreamsTest do
  use ExUnit.Case
  doctest Fedi.Streams

  require Logger

  describe "resolve" do
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
      invite_prop = List.first(invite_object.values)
      assert invite_prop.member.__struct__ == Fedi.ActivityStreams.Type.Invite

      event_object = invite_prop.member.properties["object"]
      event_prop = List.first(event_object.values)
      assert event_prop.member.__struct__ == Fedi.ActivityStreams.Type.Event

      name_object = event_prop.member.properties["name"]
      name_map_prop = List.first(name_object.mapped_values)
      assert name_map_prop.__struct__ == Fedi.ActivityStreams.Property.NameIterator
      assert is_map(name_map_prop.rdf_lang_string_member)
      assert name_map_prop.rdf_lang_string_member["en"] == "Going-Away Party for Jim"
      assert name_map_prop.unknown == nil
    end

    test "orderedCollectionPage" do
      source = """
        {
          "@context": "https://www.w3.org/ns/activitystreams",
          "id": "http://example.org/foo?page=1",
          "orderedItems": [
            {
              "name": "A Simple Note",
              "type": "Note"
            },
            {
              "name": "Another Simple Note",
              "type": "Note"
            }
          ],
          "partOf": "http://example.org/foo",
          "summary": "Page 1 of Sally's notes",
          "type": "OrderedCollectionPage"
        }
      """

      assert {:ok, page} = Fedi.Streams.JsonResolver.resolve(source)
      assert page.__struct__ == Fedi.ActivityStreams.Type.OrderedCollectionPage

      assert page.properties["orderedItems"].__struct__ ==
               Fedi.ActivityStreams.Property.OrderedItems

      assert page.properties["type"].__struct__ == Fedi.JSON.LD.Property.Type

      items = page.properties["orderedItems"]
      assert Enum.count(items.values) == 2

      note_prop = Enum.at(items.values, 0)
      assert note_prop.member.__struct__ == Fedi.ActivityStreams.Type.Note
      name_object = note_prop.member.properties["name"]
      name_prop = List.first(name_object.values)
      assert name_prop.xsd_string_member == "A Simple Note"

      note_prop = Enum.at(items.values, 1)
      assert note_prop.member.__struct__ == Fedi.ActivityStreams.Type.Note
      name_object = note_prop.member.properties["name"]
      name_prop = List.first(name_object.values)
      assert name_prop.xsd_string_member == "Another Simple Note"
    end
  end

  describe "re-serialize" do
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
      assert {:ok, json} = Fedi.Streams.Serializer.serialize(accept)

      expected = """
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "actor": {
          "name": "Sally",
          "type": "Person"
        },
        "object": {
          "actor": "http://john.example.org",
          "object": {
            "nameMap": {
              "en": "Going-Away Party for Jim",
              "fr": "Fête de départ pour Jim"
            },
            "type": "Event"
          },
          "type": "Invite"
        },
        "summary": "Sally accepted an invitation to a party",
        "type": "Accept"
      }
      """

      assert Jason.encode!(json, pretty: true) == String.trim_trailing(expected)
    end
  end
end
