defmodule Passport.Support.Web.ErrorView do
  use Passport.Support.Web, :view

  def render("parameter_missing.json", assigns) do
    %{
      errors: Enum.map(assigns[:fields], fn field ->
        %{
          status: "422",
          code: "parameter_missing",
          title: "parameter missing",
          source: %{
            parameter: "/#{field}"
          }
        }
      end)
    }
  end

  def render("locked.json", _assigns) do
    %{}
  end

  def render("unauthorized.json", _assigns) do
    %{}
  end

  def render("unauthenticated.json", _assigns) do
    %{}
  end

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.html", assigns
  end
end
