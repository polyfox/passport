# Passport

An opionated Authentication Framework for Elixir Phoenix.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `passport` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:passport, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/passport](https://hexdocs.pm/passport).

## Modules

* Activatable
* Authentication
* Confirmable
* Lockable
* Recoverable
* Rememberable - not implemented
* Trackable
* TwoFactorAuth

## Schema

### Activatable Fields

| Name | Type | Description |
| ---- | ---- | ----------- |
| `active` | `boolean` | Is the entity active, field will be available if `activatable_is_flag` is true for the entityy's config |
| `activated_at` | `utc_datetime` | When was the entity activated, field will be present if `activatable_if_flag` is false |

### Authenticatable Fields

| Name       | Type | Description |
| ---------- | ---- | ----------- |
| `password` | `string` |  `virtual` |
| `password_confirmation` | `string` | `virtual` |
| `password_changed` | `boolean` | `virtual` Was the password changed in the latest update? |
| `password_hash` | `string` | The stored password hash. |

### Confirmable Fields

| Name                 | Type     | Description |
| ----                 | ----     | ----------- |
| `confirmation_token` | `string` | A randomly generated token used to confirm the entity. |
| `confirmed_at` | `utc_datetime` | When was the entity confirmed? |
| `confirmation_sent_at` | `utc_datetime` | When was the confirmation message sent to the entity's email? |

### Lockable Fields

| Name | Type | Description |
| ---- | ---- | ----------- |
| `failed_attempts` | `integer` | How many times has the entity failed to login? |
| `locked_at` | `utc_datetime` | When was the entity locked due to login failures? |
| `lock_changed` | `boolean` | `virtual` Was the locked_at changed during the last update? |

### Recoverable Fields

| Name | Type | Description |
| ---- | ---- | ----------- |
| `reset_password_token` | `string` | A randomly generated token used to reset the user's password |
| `reset_password_sent_at` | `utc_datetime` | When was the password reset sent? |

### Rememberable Fields

| Name | Type | Description |
| ---- | ---- | ----------- |
| `remember_created_at` | `utc_datetime` |  |

### Trackable Fields

| Name | Type | Description |
| ---- | ---- | ----------- |
| `sign_in_count` | `integer` | How many times has the entity successfully authenticated and created a new session. |
| `current_sign_in_at` | `utc_datetime` | When did the entity successfully authenticate? |
| `current_sign_in_ip` | `integer` | Current IP the entity authenticated from. |
| `last_sign_in_at` | `utc_datetime` | When the entity previously authenticated? |
| `last_sign_in_ip` | `integer` | Previous IP the entity authenticated from. |

### TwoFactorAuth Fields

| Name | Type | Description |
| ---- | ---- | ----------- |
| `tfa_otp_secret_key` | `string` | The key used for generating One Time Passcodes. |
| `tfa_enabled` | `boolean` | Is Two Factor Auth enabled for the entity? |
| `tfa_attempts_count` | `integer` | How many failed two factor auth attempts have happened since last successful one? |
| `tfa_recovery_tokens` | `array<string>` | A list of tokens used in place of an otp. |

## Default Routes

### Authenticatable Routes

__Logout__

* `DELETE /login`
* `POST /logout`

__Login__

* `POST /login`

### Confirmable Routes

__Request Email Confirmation__

* `POST /confirm/email`

__Retrieve Email Confirmation Details__

* `GET /confirm/email/:token`

__Confirm Email__

* `POST /confirm/email/:token`

__Cancel Email Confirmation__

* `DELETE /confirm/email/:token`

### Recoverable Routes

__Request Password Reset__

* `POST /password`

__Complete Password Reset__

* `POST /password/:token`
* `PATCH /password/:token`
* `PUT /password/:token`

__Cancel Password Reset__

* `DELETE /password/:token`

### TwoFactorAuth Routes

__Reset TFA Secret__

* `POST /reset/tfa`

__Confirm TFA__

* `POST /confirm/tfa`

## Usage

### Schema

```bash
$ mix passport.init
```

### Models

By default Passport includes all it's available

```elixir
defmodule MyApp.User do
  use Ecto.Schema

  schema "users" do
    timestamps()

    field :email, :string

    Passport.schema_fields()
  end
end
```

### Controllers

```elixir
defmodule MyApp.Web.ConfirmationController do
  use MyApp.Web, :controller
  use Passport.ConfirmationController, confirmable_model: MyApp.User
end
```

```elixir
defmodule MyApp.Web.PasswordController do
  use MyApp.Web, :controller
  use Passport.PasswordController, recoverable_model: MyApp.User

  @impl true
  def request_reset_password(params) do
    email = params["email"]
    case Passport.Repo.replica().get_by!(Passport.Support.User, email: email) do
      nil ->
        {:error, :not_found}
      entity ->
        Passport.prepare_reset_password(entity)
    end
  end
end
```

```elixir
defmodule MyApp.Web.SessionController do
  use MyApp.Web, :controller
  use Passport.SessionController
end
```

```elixir
defmodule MyApp.Web.TwoFactorAuthController do
  use MyApp.Web, :controller
  use Passport.TwoFactorAuthController
end
```
