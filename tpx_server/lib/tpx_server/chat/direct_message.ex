defmodule TpxServer.Chat.DirectMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "direct_messages" do
    field :user_a, :binary_id
    field :user_b, :binary_id
    field :last_message_at, :naive_datetime
    timestamps()
  end

  def create_changeset(dm, attrs) do
    dm
    |> cast(attrs, [:user_a, :user_b])
    |> validate_required([:user_a, :user_b])
    |> unique_constraint(:user_a, name: :direct_messages_user_a_user_b_index)
  end
end
