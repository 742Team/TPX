defmodule TpxServer.Chat.Group do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "groups" do
    field :name, :string
    field :description, :string
    field :photo, :string
    field :owner_id, :binary_id
    field :admins, {:array, :binary_id}, default: []
    field :members, {:array, :binary_id}, default: []
    field :banned_users, {:array, :binary_id}, default: []
    field :messages_retention, :integer
    field :join_password_hash, :string
    timestamps()
  end

  def create_changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :description,
      :photo,
      :owner_id,
      :admins,
      :members,
      :banned_users,
      :messages_retention,
      :join_password_hash
    ])
    |> validate_required([:name, :owner_id])
  end
end
