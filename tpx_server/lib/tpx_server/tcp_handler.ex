defmodule TpxServer.TCPHandler do
  use ThousandIsland.Handler

  def handle_connection(socket, _state) do
    :ok = ThousandIsland.Socket.setopts(socket, active: false)
    session_id = :erlang.unique_integer([:monotonic, :positive])
    state = %{session_id: session_id, last_seq: 0, authed: false}
    loop(socket, state)
  end

  defp loop(socket, state) do
    case ThousandIsland.Socket.recv(socket, 0) do
      {:ok, data} ->
        case Msgpax.unpack(data) do
          {:ok, msg} ->
            new_state = handle_msg(socket, msg, state)
            loop(socket, new_state)

          _ ->
            loop(socket, state)
        end

      {:error, _} ->
        :ok
    end
  end

  defp handle_msg(
         socket,
         %{"type" => "client_hello", "token" => token, "version" => _ver, "seq" => seq},
         state
       ) do
    if seq <= state.last_seq do
      state
    else
      authed = validate_token(token)

      reply = %{
        "type" => "server_hello",
        "ok" => authed,
        "session_id" => state.session_id,
        "ack" => seq
      }

      _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(reply))
      %{state | authed: authed, last_seq: seq}
    end
  end

  defp handle_msg(socket, %{"type" => "ping", "seq" => seq}, state) do
    ack = %{"type" => "pong", "ack" => seq}
    _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(ack))
    %{state | last_seq: max(state.last_seq, seq)}
  end

  defp handle_msg(_socket, _msg, state), do: state

  defp validate_token(_token), do: true
end
