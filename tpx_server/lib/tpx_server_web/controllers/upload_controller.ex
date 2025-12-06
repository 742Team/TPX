defmodule TpxServerWeb.UploadController do
  use TpxServerWeb, :controller

  def create(conn, %{"file" => %Plug.Upload{filename: filename, path: tmp_path}}) do
    dest_dir = Application.app_dir(:tpx_server, "priv/static/images/uploads")
    :ok = File.mkdir_p(dest_dir)
    id = Ecto.UUID.generate()
    dest_name = id <> "_" <> filename
    dest_path = Path.join(dest_dir, dest_name)

    case File.cp(tmp_path, dest_path) do
      :ok ->
        content_type = MIME.from_path(filename) || "application/octet-stream"
        size = File.stat!(dest_path).size

        json(conn, %{
          ok: true,
          url: "/images/uploads/" <> dest_name,
          content_type: content_type,
          size: size
        })

      {:error, _} ->
        conn |> put_status(500) |> json(%{ok: false})
    end
  end

  def create(conn, _), do: conn |> put_status(400) |> json(%{ok: false})
end
