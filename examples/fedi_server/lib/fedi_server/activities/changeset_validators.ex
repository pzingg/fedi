defmodule FediServer.Activities.ChangesetValidators do
  import Ecto.Changeset

  require Logger

  alias Fedi.Streams.Utils

  def validate_id(changeset) do
    existing_id = get_field(changeset, :id)

    cond do
      get_field(changeset, :local) ->
        ap_id = get_field(changeset, :ap_id)
        %URI{path: ap_id_path} = Utils.to_uri(ap_id)
        id = Path.basename(ap_id_path)

        case existing_id do
          nil ->
            put_change(changeset, :id, id)

          ^id ->
            changeset

          _ ->
            add_error(changeset, :ap_id, "does not match id #{id}")
        end

      is_nil(existing_id) ->
        put_change(changeset, :id, Ecto.ULID.generate())

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