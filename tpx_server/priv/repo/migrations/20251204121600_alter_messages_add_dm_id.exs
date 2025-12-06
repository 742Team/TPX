defmodule TpxServer.Repo.Migrations.AlterMessagesAddDmId do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :dm_id, :binary_id
    end

    create index(:messages, [:dm_id, :inserted_at])
  end
end
