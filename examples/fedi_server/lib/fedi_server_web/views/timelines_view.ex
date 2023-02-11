defmodule FediServerWeb.TimelinesView do
  use FediServerWeb, :view

  def description(activity) do
    actor = activity["actor"]

    case activity["type"] do
      "Create" -> "#{actor} posted"
      "Update" -> "#{actor} edited"
      type -> "#{actor} #{String.downcase(type)}d"
    end
  end

  def object(activity) do
    case activity["object"] do
      object when is_binary(object) ->
        object

      object when is_map(object) ->
        object_id = object["id"]

        case object["type"] do
          "Note" ->
            object["content"]

          "Tombstone" ->
            type = object["formerType"]
            "#{object_id}, a #{String.downcase(type)}"

          type ->
            "#{object_id}, a #{String.downcase(type)}"
        end

      nil ->
        "<nothing>"

      object ->
        "#{inspect(object)}"
    end
  end
end
