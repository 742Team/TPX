defmodule TpxServer.Repo.Migrations.AlterMessagesGroupIdNullable do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      modify :group_id, :binary_id, null: true
    end
  end
end
