defmodule TpxServer.Repo.Migrations.AlterUsersAddHeaderBackground do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :header_background, :string
    end
  end
end
