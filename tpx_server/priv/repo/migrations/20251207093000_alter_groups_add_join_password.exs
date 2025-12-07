defmodule TpxServer.Repo.Migrations.AlterGroupsAddJoinPassword do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :join_password_hash, :string
    end
  end
end
