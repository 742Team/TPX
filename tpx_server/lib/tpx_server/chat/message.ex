defmodule TpxServer.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :sender_id, :binary_id
    field :group_id, :binary_id
    field :dm_id, :binary_id
    field :type, :string
    field :content, :map
    field :encryption_metadata, :map
    field :edited_at, :naive_datetime
    field :deleted, :boolean, default: false
    field :pinned, :boolean, default: false
    field :pinned_at, :naive_datetime
    timestamps(updated_at: false)
  end

  def create_changeset(msg, attrs) do
    msg
    |> cast(attrs, [:sender_id, :group_id, :dm_id, :type, :content, :encryption_metadata])
    |> validate_required([:sender_id, :type])
    |> require_one_of([:group_id, :dm_id])
    |> validate_inclusion(:type, ["text", "image", "video", "audio", "file", "system"])
  end

  defp require_one_of(changeset, fields) do
    present = Enum.filter(fields, fn f -> get_field(changeset, f) end)

    case present do
      [] -> add_error(changeset, hd(fields), "one of fields must be present")
      _ -> changeset
    end
  end
end
