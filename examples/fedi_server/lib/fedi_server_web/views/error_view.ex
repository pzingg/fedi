defmodule FediServerWeb.ErrorView do
  use FediServerWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  def render("404.html", _assigns) do
    "Object not found"
  end

  def render("410.html", _assigns) do
    "Object was deleted"
  end

  def render("422.html", _assigns) do
    "Activity validation error"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
