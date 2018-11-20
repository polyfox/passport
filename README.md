# Passport

An opionated Authentication Framework for Elixir Phoenix.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `passport` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:passport, "~> 0.3.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/passport](https://hexdocs.pm/passport).

## Modules

* Activatable `activatable`
* Authenticatable `authenticatable`
* Confirmable `confirmable`
* Lockable `lockable`
* Recoverable `recoverable`
* Rememberable `rememberable` - not implemented
* Trackable `trackable`
* TwoFactorAuth `two_factor_auth`

## Schema

### Activatable Fields

| Name | Type | Description |
| ---- | ---- | ----------- |
| `active` | `boolean` | Is the entity active, field will be available if `activatable_is_flag` is true for the entityy's config |
| `activated_at` | `utc_datetime` | When was the entity activated, field will be present if `activatable_if_flag` is false |

### Authenticatable Fields

| Name       | Type | Description |
| ---------- | ---- | ----------- |
| `old_password` | `string` | `virtual` |
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

Provided by `Passport.SessionController`

__Logout__

* `DELETE /login`
* `POST /logout`

__Login__

* `POST /login`

### Confirmable Routes

Provided by `Passport.ConfirmationController`

__Request Email Confirmation__

* `POST /confirm/email`

__Retrieve Email Confirmation Details__

* `GET /confirm/email/:token`

__Confirm Email__

* `POST /confirm/email/:token`

__Cancel Email Confirmation__

* `DELETE /confirm/email/:token`

### Recoverable Routes

Provided by `Passport.PasswordController`

__Request Password Reset__

* `POST /password`

__Complete Password Reset__

* `POST /password/:token`
* `PATCH /password/:token`
* `PUT /password/:token`

__Cancel Password Reset__

* `DELETE /password/:token`

### TwoFactorAuth Routes

Provided by `Passport.TwoFactorController`

__Reset TFA Secret__

* `POST /reset/tfa`

__Confirm TFA__

* `POST /confirm/tfa`

## Usage

### Config

Passport has a handful of config options that are required for the library to work correctly:

```elixir
config :passport,
  # the phoenix error view to use when rendering the api errors
  error_view: Passport.Support.Web.ErrorView,
  # a context module used for creating, retrieiving and managing sessions
  sessions_client: Passport.Support.Sessions,
  # the writable ecto repository, can be the same as the replica
  primary_repo: Passport.Support.Repo,
  # the readable ecto repository, can be the same as the primary
  replica_repo: Passport.Support.Repo
```

### Schema

```bash
#$ mix passport.init ModelName table_name
$ mix passport.init User users
```

### Models

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

By default Passport includes all it's available modules, individual modules can chosen by providing a list to the schema_fields call

```elixir
Passport.schema_fields([:authenticatable, :lockable, :two_factor_auth])
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

### Contexts

Passport only requires a single context to be implemented, it's Sessions context, there it will handle retrieving sessions and their entities as well as checking authentication details.

The module must be configered via `config :passport, sessions_client: ModuleName`

```elixir
defmodule Passport.Support.Sessions do
  # imports extract_password/1 and extract_auth_code/1
  use Passport.Sessions

  @impl true
  def find_entity_by_identity(identity) do
    Passport.Support.Users.find_user_by_email(identity)
  end

  @impl true
  def check_authentication(entity, params) do
    Passport.check_authenticatable(entity, extract_password(params))
  end

  @impl true
  def create_session(entity, _params) do
    # for simplicity sake use the entity's id as the token
    {:ok, {entity.id, entity}}
  end

  @impl true
  def get_session(token) do
    {:ok, [user: Passport.Support.Users.get_user(token), token: token]}
  end

  @impl true
  def destroy_session(%{user: user} = assigns) do
    # nothing to do here, we don't exactly have an api keys table yet
    {:ok, user}
  end
end
```

### Issuing a Password Change

```elixir
# for immediately changing it
{:ok, entity} =
  Passport.change_password(entity, %{
    old_password: "my_old_password",
    password: "new_password",
    password_confirmation: "new_password"
  })
# as apart of a changeset
changeset =
  Passport.changeset(entity, %{
    old_password: "my_old_password",
    password: "new_password",
    password_confirmation: "new_password"
  }, :password_change)
```
