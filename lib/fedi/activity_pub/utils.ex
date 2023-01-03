defmodule Fedi.ActivityPub.Utils do
  @moduledoc false

  require Logger

  @content_type_header "content-type"
  @accept_header "accept"
  @content_type_value "application/ld+json; profile=\"https:www.w3.org/ns/activitystreams\""
  @public_activity_pub_iri "https:www.w3.org/ns/activitystreams#Public"
  @public_json_ld "Public"
  @public_json_ld_as "as:Public"

  @doc """
  err_object_reequired indicates the activity needs its object property
  set. Can be returned by DelegateActor's PostInbox or PostOutbox so a
  Bad Request response is set.
  """
  def err_object_required do
    {:err_object_required, "Object property required on the provided activity"}
  end

  @doc """
  err_target_required indicates the activity needs its target property
  set. Can be returned by DelegateActor's PostInbox or PostOutbox so a
  Bad Request response is set.
  """
  def err_target_required do
    {:err_target_required, "Target property required on the provided activity"}
  end

  @doc """
  activity_streams_media_types contains all of the accepted ActivityStreams media
  types. Generated at init time.
  """
  def activity_streams_media_types do
    types = [
      "application/activity+json"
    ]

    semis = [";", " ;", " ; ", "; "]

    profiles = [
      "profile=https:www.w3.org/ns/activitystreams",
      "profile=\"https:www.w3.org/ns/activitystreams\""
    ]

    Enum.reduce(semis, types, fn semi, acc ->
      Enum.reduce(profiles, acc, fn profile, acc2 ->
        ["application/ld+json#{semi}#{profile}" | acc2]
      end)
    end)
    |> Enum.reverse()
  end

  def is_activity_pub_media_type(%Plug.Conn{} = conn, which_header) do
    Plug.Conn.get_req_header(conn, which_header)
    |> header_is_activity_pub_media_type()
  end

  @doc """
  header_is_activity_pub_media_type returns true if the header string contains one
  of the accepted ActivityStreams media types.

  Note we don't try to build a comprehensive parser and instead accept a
  tolerable amount of whitespace since the HTTP specification is ambiguous
  about the format and significance of whitespace.
  """
  def header_is_activity_pub_media_type([]), do: false

  def header_is_activity_pub_media_type([header | _]) do
    header_is_activity_pub_media_type(header)
  end

  def header_is_activity_pub_media_type(header) when is_binary(header) do
    found =
      Enum.find(activity_streams_media_types(), fn media_type ->
        String.contains?(header, media_type)
      end)

    !is_nil(found)
  end

  @doc """
  Returns true if the request is a POST request that has the
  ActivityStreams "content-type" header
  """
  def is_activity_pub_post(%Plug.Conn{} = conn) do
    conn.method == "POST" && is_activity_pub_media_type(conn, @content_type_header)
  end

  @doc """
  Returns true if the request is a GET request that has the
  ActivityStreams "accept" header
  """
  def is_activity_pub_get(%Plug.Conn{} = conn) do
    conn.method == "GET" && is_activity_pub_media_type(conn, @accept_header)
  end

  def decode_json_body(%Plug.Conn{} = conn) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, length: 25_000_000),
         {:ok, json} <- Jason.decode(body) do
      {:ok, {conn, json}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the IRI that indicates an Activity is meant
  to be visible for general public consumption.
  """
  def public_activity_pub_iri, do: @public_activity_pub_iri

  @doc """
  Determines if an IRI string is the Public collection as defined in
  the spec, including JSON-LD compliant collections.
  """
  def is_public(str) when is_binary(str) do
    str == @public_activity_pub_iri ||
      str == @public_json_ld ||
      str == @public_json_ld_as
  end

  @doc """
  deduplicates the 'orderedItems' within an ordered
  collection type. Deduplication happens by the 'id' property.
  """
  def dedupe_ordered_items(ordered_collection) do
    case Fedi.Streams.Utils.get_ordered_items(ordered_collection) do
      %{values: oi_iterator_props} = ordered_items when is_list(oi_iterator_props) ->
        {deduped, dropped, _seen} =
          oi_iterator_props
          |> Enum.with_index()
          |> Enum.reduce_while({[], 0, MapSet.new()}, fn {prop, idx}, {acc, dropped, seen} ->
            case Fedi.Streams.Utils.get_id_or_iri(prop) do
              %URI{} = id ->
                id = URI.to_string(id)

                if MapSet.member?(seen, id) do
                  {:cont, {acc, dropped + 1, seen}}
                else
                  {:cont, {[prop | acc], dropped, MapSet.put(seen, id)}}
                end

              _ ->
                {:halt,
                 {:error,
                  "element #{idx + 1} in OrderedCollection does not have an ID nor is an IRI"}}
            end
          end)

        if dropped == 0 do
          {:ok, ordered_collection}
        else
          ordered_items = struct(ordered_items, values: Enum.reverse(deduped))
          {:ok, Fedi.Streams.Utils.set_ordered_items(ordered_collection, ordered_items)}
        end

      _ ->
        {:error, "No orderedItems in collection"}
    end
  end

  @doc """
  Sets headers needed in the HTTP response, such but not
  limited to the Content-Type, Date, and Digest headers.
  """
  def add_response_headers(%Plug.Conn{} = conn, body) do
    date_str =
      DateTime.utc_now()
      |> Timex.format!("{RFC822z}")
      |> String.replace_trailing("Z", "GMT")

    hashed = :crypto.hash(:sha256, body) |> Base.encode64()

    [
      {@content_type_header, @content_type_value},
      # RFC 7231 §7.1.1.2
      {"date", date_str},
      # RFC 3230 and RFC 5843
      {"digest", "SHA-256=#{hashed}"}
    ]
    |> Enum.reduce(conn, fn {key, value}, acc ->
      Plug.Conn.put_resp_header(acc, key, value)
    end)
  end

  def send_text_resp(%Plug.Conn{} = conn, status, body) do
    conn
    |> Plug.Conn.put_resp_header(@content_type_header, "text/plain")
    |> Plug.Conn.send_resp(status, body)
  end

  def send_text_resp(%Plug.Conn{} = conn, status, body, actor_state) do
    conn
    |> Plug.Conn.put_private(:actor_state, actor_state)
    |> Plug.Conn.put_resp_header(@content_type_header, "text/plain")
    |> Plug.Conn.send_resp(status, body)
  end

  def is_or_extends_activity(as_value) do
    with mod_parts <- Module.split(as_value.__struct__),
         {["Fedi", "ActivityStreams", "Type"], [type]} <- Enum.split(mod_parts, -1),
         activity_types <- ["Activity" | Fedi.ActivityStreams.Type.Activity.Meta.extended_by()] do
      Enum.member?(activity_types, type)
    else
      _ -> false
    end
  end

  @doc """
  Verifies that a value is an Activity with a valid id.
  """
  def valid_activity(as_value) when is_struct(as_value) do
    if is_or_extends_activity(as_value) do
      case Fedi.Streams.Utils.get_json_ld_id(as_value) do
        %URI{} = id ->
          {:ok, {as_value, id}}

        _ ->
          {:error, {:err_missing_id, "Activity does not have an id"}}
      end
    else
      {:error, "ActivityStreams value is not an Activity: #{as_value.__struct__}"}
    end
  end

  def valid_activity(as_value) do
    {:error, "ActivityStreams value is not a type: #{inspect(as_value)}"}
  end

  @doc """
  Forms an ActivityPub id based on the HTTP request.
  """
  def request_id(%Plug.Conn{host: host, port: port, request_path: path}, scheme) do
    %URI{scheme: scheme, host: host, port: port, path: path}
  end
end
