defmodule Passport.Support.Web.ErrorView do
  use Passport.Support.Web, :view

  def render("unauthorized.json", assigns) do
    %{errors: [%{status: "401", code: "unauthorized", title: "Unauthorized", detail: assigns[:reason]}]}
  end

  def render("unauthenticated.json", assigns) do
    %{errors: [%{status: "401", code: "unauthenticated", title: "Unauthenticated", detail: assigns[:reason]}]}
  end

  def render("403.json", assigns) do
    %{errors: [%{status: "403", code: "forbidden", title: "Forbidden", detail: assigns[:reason]}]}
  end

  def render("parameter_missing.json", assigns) do
    %{
      errors: Enum.map(assigns[:fields], fn field ->
        %{
          status: "422",
          code: "parameter_missing",
          title: "Parameter Missing",
          source: %{
            parameter: "/#{field}"
          }
        }
      end)
    }
  end

  def render("parameter_invalid.json", assigns) do
    %{
      errors: Enum.map(assigns[:fields], fn field ->
        %{
          status: "422",
          code: "parameter_invalid",
          title: "Parameter Invalid",
          source: %{
            parameter: "/#{field}"
          }
        }
      end)
    }
  end

  def render("locked.json", assigns) do
    %{errors: [%{status: "423", code: "locked", title: "Locked", detail: assigns[:reason]}]}
  end

  def render("precondition_required.json", assigns) do
    %{errors: [%{status: "428", code: "precondition_required", title: "Precondition Required", detail: assigns[:reason]}]}
  end

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", assigns) do
    "Internal server error"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.html", assigns
  end
end
