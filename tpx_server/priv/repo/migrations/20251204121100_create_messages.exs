defmodule TpxServer.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sender_id, :binary_id, null: false
      add :group_id, :binary_id, null: false
      add :type, :string, null: false
      add :content, :map
      add :encryption_metadata, :map
      add :edited_at, :naive_datetime
      add :deleted, :boolean, null: false, default: false
      timestamps(updated_at: false)
    end

    create index(:messages, [:group_id, :inserted_at])
  end
end
