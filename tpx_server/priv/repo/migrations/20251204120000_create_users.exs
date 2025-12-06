defmodule TpxServer.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :display_name, :string
      add :photo, :string
      add :background, :string
      add :status, :string, null: false, default: "offline"
      add :public_key, :string
      add :blocked_users, {:array, :binary_id}, null: false, default: []
      add :password_hash, :string, null: false
      timestamps()
    end

    create unique_index(:users, [:username])
  end
end
