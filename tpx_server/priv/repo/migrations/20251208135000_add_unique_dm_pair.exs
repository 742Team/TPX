defmodule TpxServer.Repo.Migrations.AddUniqueDmPair do
  use Ecto.Migration

  def change do
    drop_if_exists index(:direct_messages, [:user_a, :user_b])
    create unique_index(:direct_messages, [:user_a, :user_b])
  end
end
