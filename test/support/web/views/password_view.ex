defmodule Passport.Support.Web.PasswordView do
  use Passport.Support.Web, :view

  def render("no_content.json", _assigns), do: %{}

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
