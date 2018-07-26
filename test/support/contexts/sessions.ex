defmodule Passport.Support.Sessions do
  use Passport.Sessions

  @impl true
  def find_entity_by_identity(identity) do
    Passport.Support.Users.find_user_by_email(identity)
  end

  @impl true
  def check_authentication(entity, password) do
    Passport.check_authenticatable(entity, password)
  end

  @impl true
  def create_session(entity) do
    # for simplicity sake use the entity's id as the token
    {:ok, {entity.id, entity}}
  end

  @impl true
  def get_session(token) do
    {:ok, [user: Passport.Support.Users.get_user(token), token: token]}
  end

  @impl true
  def destroy_session(%{user: user}) do
    # nothing to do here, we don't exactly have an api keys table yet
    {:ok, user}
  end
end
