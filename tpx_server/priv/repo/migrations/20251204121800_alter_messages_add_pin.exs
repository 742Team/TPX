defmodule TpxServer.Repo.Migrations.AlterMessagesAddPin do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :pinned, :boolean, default: false
      add :pinned_at, :naive_datetime
    end

    create index(:messages, [:group_id, :pinned])
    create index(:messages, [:dm_id, :pinned])
  end
end
