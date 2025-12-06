defmodule TpxServer.Repo.Migrations.CreateDirectMessages do
  use Ecto.Migration

  def change do
    create table(:direct_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_a, :binary_id, null: false
      add :user_b, :binary_id, null: false
      add :last_message_at, :naive_datetime
      timestamps()
    end

    create index(:direct_messages, [:user_a, :user_b])
  end
end
