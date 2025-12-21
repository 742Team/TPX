defmodule TpxServer.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :display_name, :string
    field :photo, :string
    field :background, :string
    field :header_background, :string
    field :status, :string, default: "offline"
    field :public_key, :string
    field :blocked_users, {:array, :binary_id}, default: []
    field :password, :string, virtual: true
    field :password_hash, :string
    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :display_name,
      :photo,
      :background,
      :header_background,
      :status,
      :public_key,
      :blocked_users,
      :password
    ])
    |> validate_required([:username, :password])
    |> validate_length(:username, min: 3, max: 32)
    |> validate_format(:username, ~r/^[-_a-zA-Z0-9]+$/)
    |> validate_length(:password, min: 6)
    |> validate_inclusion(:status, ["online", "offline", "custom"])
    |> unique_constraint(:username)
    |> put_pass_hash()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :photo, :background, :header_background])
  end

  def status_changeset(user, attrs) do
    user
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, ["online", "offline", "custom"])
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_length(:password, min: 6)
    |> put_pass_hash()
  end

  defp put_pass_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      pass -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(pass))
    end
  end
end
