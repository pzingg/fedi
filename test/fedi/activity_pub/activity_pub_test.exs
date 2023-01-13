defmodule Fedi.ActivityPubTest do
  use ExUnit.Case
  # doctest Fedi.ActivityPub

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils

  defmodule MockDatabase do
    @moduledoc false

    def start_link() do
      Agent.start_link(fn -> 1 end, name: __MODULE__)
    end

    def new_id(value) do
      with {:ok, {_type_name, category}} <- Utils.get_type_name_and_category(value) do
        id = Agent.get_and_update(__MODULE__, fn id -> {id, id + 1} end)
        last_four = Integer.to_string(id) |> String.pad_leading(4, "0")
        ulid = "01GP9EBWC2BTW0R98JJF2X" <> last_four

        case category do
          :actors -> {:error, "Cannot make new id for actors"}
          :activities -> {:ok, URI.parse("https://example.com/activities/#{ulid}")}
          _ -> {:ok, URI.parse("https://example.com/objects/#{ulid}")}
        end
      end
    end
  end

  defmodule MockActor do
    @moduledoc false

    defstruct [
      :common,
      :c2s,
      :s2s,
      :c2s_resolver,
      :s2s_resolver,
      :fallback,
      :database,
      :enable_social_protocol,
      :enable_federated_protocol,
      :data
    ]
  end

  test "user_agent is configured" do
    assert Application.get_env(:fedi, :user_agent) == "(elixir-fedi-0.1.0)"
  end

  test "SideEffectActor adds new ids" do
    source = """
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "actor": {
          "name": "Sally",
          "type": "Person"
        },
        "object": {
          "content": "This is a simple note",
          "name": "A Simple Note",
          "type": "Note"
        },
        "summary": "Sally created a note",
        "type": "Create"
      }
    """

    MockDatabase.start_link()

    mock_actor = %MockActor{
      database: MockDatabase
    }

    assert {:ok, create} = Fedi.Streams.JSONResolver.resolve(source)
    assert create.__struct__ == Fedi.ActivityStreams.Type.Create
    assert is_nil(APUtils.get_id(create))
    note = Utils.get_object(create) |> Map.get(:values) |> hd() |> Map.get(:member)
    assert note.__struct__ == Fedi.ActivityStreams.Type.Note
    assert is_nil(APUtils.get_id(note))

    assert {:ok, create} = Fedi.ActivityPub.SideEffectActor.add_new_ids(mock_actor, create)
    assert create.__struct__ == Fedi.ActivityStreams.Type.Create
    %URI{path: path} = APUtils.get_id(create)
    assert path == "/activities/01GP9EBWC2BTW0R98JJF2X0001"

    note = Utils.get_object(create) |> Map.get(:values) |> hd() |> Map.get(:member)
    assert note.__struct__ == Fedi.ActivityStreams.Type.Note
    %URI{path: path} = APUtils.get_id(note)
    assert path == "/objects/01GP9EBWC2BTW0R98JJF2X0002"
  end
end
