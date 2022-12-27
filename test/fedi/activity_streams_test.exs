defmodule Fedi.StreamsTest do
  use ExUnit.Case
  doctest Fedi.Streams

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
  end
end
