defmodule Passport.APIHelper do
  alias Passport.Config
  import Phoenix.Controller
  import Plug.Conn

  defp send_error(conn, status, name, assigns) do
    conn
    |> put_status(status)
    |> put_view(Config.error_view())
    |> Phoenix.Controller.render(name, assigns)
    |> Plug.Conn.halt()
  end

  # 204
  def send_no_content(conn, assigns \\ []) do
    # Not really an error
    send_error(conn, 204, "no_content.json", assigns)
  end

  # 401
  def send_unauthenticated(conn, assigns \\ []) do
    send_error(conn, 401, "unauthenticated.json", assigns)
  end

  # 401
  def send_unauthorized(conn, assigns \\ []) do
    send_error(conn, 401, "unauthorized.json", assigns)
  end

  # 403
  def send_forbidden(conn, assigns \\ []) do
    send_error(conn, 403, "403.json", assigns)
  end

  # 404
  def send_not_found(conn, assigns \\ []) do
    send_error(conn, 404, "404.json", assigns)
  end

  # 409
  def send_conflict(conn, assigns \\ []) do
    send_error(conn, 409, "conflict.json", assigns)
  end

  # 422
  def send_parameter_missing(conn, assigns \\ []) do
    send_error(conn, 422, "parameter_missing.json", assigns)
  end

  def send_parameter_invalid(conn, assigns \\ []) do
    send_error(conn, 422, "parameter_invalid.json", assigns)
  end

  def send_changeset_error(conn, assigns \\ []) do
    send_error(conn, 422, "error.json", assigns)
  end

  # 423
  def send_locked(conn, assigns \\ []) do
    send_error(conn, 423, "locked.json", assigns)
  end

  # 428
  def send_precondition_required(conn, assigns) do
    send_error(conn, 428, "precondition_required.json", assigns)
  end

  # 500
  def send_server_error(conn, assigns \\ []) do
    send_error(conn, 500, "500.json", assigns)
  end
end
