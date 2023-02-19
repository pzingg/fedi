defmodule FediServer.Activities.ChangesetValidators do
  import Ecto.Changeset

  require Logger

  alias Fedi.Streams.Utils

  def validate_id(changeset) do
    existing_id = get_field(changeset, :id)

    cond do
      get_field(changeset, :local?) ->
        ap_id = get_field(changeset, :ap_id)
        %URI{path: ap_id_path} = Utils.to_uri(ap_id)
        id = Path.basename(ap_id_path)

        case existing_id do
          nil ->
            Logger.error("no id in local changeset, got #{id} from ap_id")
            put_change(changeset, :id, id)

          ^id ->
            Logger.error("id in local changeset matches #{id} from ap_id")
            changeset

          _ ->
            Logger.error("id #{existing_id} in local changeset does not match #{id} from ap_id")
            add_error(changeset, :ap_id, "does not match id #{id}")
        end

      is_nil(existing_id) ->
        id = Ecto.ULID.generate()
        Logger.error("changeset #{inspect(changeset)} is not local, generating id #{id}")
        put_change(changeset, :id, id)

      true ->
        changeset
    end
  end

  def maybe_set_public(changeset) do
    data = get_field(changeset, :data, %{})
    to = Map.get(data, "to", []) |> List.wrap()
    cc = Map.get(data, "cc", []) |> List.wrap()

    {public?, listed?} =
      cond do
        Enum.any?(to, fn iri -> Utils.public?(iri) end) ->
          # :public
          {true, true}

        Enum.any?(cc, fn iri -> Utils.public?(iri) end) ->
          # :unlisted
          {true, false}

        true ->
          # :followers_only, :direct
          {false, false}
      end

    changeset
    |> put_change(:public?, public?)
    |> put_change(:listed?, listed?)
  end
end
