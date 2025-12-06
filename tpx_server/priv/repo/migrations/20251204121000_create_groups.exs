defmodule TpxServer.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :string
      add :photo, :string
      add :owner_id, :binary_id, null: false
      add :admins, {:array, :binary_id}, null: false, default: []
      add :members, {:array, :binary_id}, null: false, default: []
      add :banned_users, {:array, :binary_id}, null: false, default: []
      add :messages_retention, :integer
      timestamps()
    end

    create index(:groups, [:owner_id])
  end
end
