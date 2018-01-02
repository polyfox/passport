defmodule Passport.Support.Web.LayoutView do
  use Passport.Support.Web, :view

  def render("no_content.json", _assigns) do
    %{}
  end

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
end
