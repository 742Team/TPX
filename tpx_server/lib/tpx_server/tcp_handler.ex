defmodule TpxServer.TCPHandler do
  use ThousandIsland.Handler
  alias TpxServer.Accounts
  alias TpxServerWeb.Endpoint

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
            new_state = handle_text(socket, data, state)
            loop(socket, new_state)
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

  defp handle_msg(socket, %{"type" => "command", "cmd" => "register", "seq" => seq}, state) do
    if seq <= state.last_seq do
      state
    else
      prompt = %{"type" => "prompt", "name" => "register", "step" => "username"}
      _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(prompt))
      _ = ThousandIsland.Socket.send(socket, "enter username:\n")
      %{state | last_seq: seq, interaction: %{name: :register, step: :username, data: %{}, seq: seq}}
    end
  end

  defp handle_msg(socket, %{"type" => "register", "action" => "start", "seq" => seq}, state) do
    if seq <= state.last_seq do
      state
    else
      prompt = %{"type" => "prompt", "name" => "register", "step" => "username"}
      _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(prompt))
      _ = ThousandIsland.Socket.send(socket, "enter username:\n")
      %{state | last_seq: seq, interaction: %{name: :register, step: :username, data: %{}, seq: seq}}
    end
  end

  defp handle_msg(socket, %{"type" => "input", "value" => value, "seq" => seq}, %{interaction: %{name: :register} = inter} = state) do
    step = inter.step
    data = inter.data
    cond do
      step == :username ->
        next = %{name: :register, step: :password, data: Map.put(data, :username, String.trim(value)), seq: seq}
        _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(%{"type" => "prompt", "name" => "register", "step" => "password"}))
        _ = ThousandIsland.Socket.send(socket, "enter password:\n")
        %{state | last_seq: seq, interaction: next}

      step == :password ->
        next = %{name: :register, step: :confirm, data: Map.put(data, :password, value), seq: seq}
        _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(%{"type" => "prompt", "name" => "register", "step" => "confirm"}))
        _ = ThousandIsland.Socket.send(socket, "confirm password:\n")
        %{state | last_seq: seq, interaction: next}

      step == :confirm ->
        if value == Map.get(data, :password) do
          next = %{name: :register, step: :display_name, data: data, seq: seq}
          _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(%{"type" => "prompt", "name" => "register", "step" => "display_name"}))
          _ = ThousandIsland.Socket.send(socket, "enter display name:\n")
          %{state | last_seq: seq, interaction: next}
        else
          _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(%{"type" => "error", "name" => "register", "step" => "confirm", "reason" => "mismatch"}))
          _ = ThousandIsland.Socket.send(socket, "password mismatch, try again:\n")
          _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(%{"type" => "prompt", "name" => "register", "step" => "confirm"}))
          %{state | last_seq: seq}
        end

      step == :display_name ->
        params = %{
          "username" => Map.get(data, :username),
          "password" => Map.get(data, :password),
          "display_name" => String.trim(value)
        }
        case Accounts.register_user(params) do
          {:ok, user} ->
            token = Phoenix.Token.sign(Endpoint, "user_auth", user.id)
            reply = %{"type" => "register_ok", "user_id" => user.id, "token" => token}
            _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(reply))
            _ = ThousandIsland.Socket.send(socket, "registered\n")
            _ = ThousandIsland.Socket.send(socket, ("token:" <> token <> "\n"))
            %{state | last_seq: seq, interaction: nil}
          {:error, _changeset} ->
            _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(%{"type" => "error", "name" => "register", "step" => "display_name", "reason" => "invalid"}))
            _ = ThousandIsland.Socket.send(socket, "register failed\n")
            %{state | last_seq: seq}
        end

      true ->
        %{state | last_seq: seq}
    end
  end

  defp handle_msg(socket, %{"type" => "cancel", "seq" => seq}, %{interaction: %{name: :register}} = state) do
    _ = ThousandIsland.Socket.send(socket, Msgpax.pack!(%{"type" => "register_cancelled"}))
    %{state | last_seq: seq, interaction: nil}
  end

  defp handle_msg(_socket, _msg, state), do: state

  defp handle_text(socket, data, state) when is_binary(data) do
    line = data |> to_string() |> String.trim()
    cond do
      line == "" -> state

      Map.get(state, :interaction) && Map.get(state.interaction, :name) == :register ->
        # Treat line as input value for current step
        case line do
          "esc" ->
            _ = ThousandIsland.Socket.send(socket, "register cancelled\n")
            %{state | interaction: nil}
          _ ->
            # Reuse structured input handler with seq bump
            seq = (state.last_seq || 0) + 1
            handle_msg(socket, %{"type" => "input", "value" => line, "seq" => seq}, state)
        end

      line == "register" or line == "Usage: register" ->
        seq = (state.last_seq || 0) + 1
        handle_msg(socket, %{"type" => "register", "action" => "start", "seq" => seq}, state)

      String.starts_with?(line, "register ") ->
        parts = String.split(line, ~r/\s+/, trim: true)
        case parts do
          [_, username, password, display_name] ->
            params = %{"username" => username, "password" => password, "display_name" => display_name}
            case Accounts.register_user(params) do
              {:ok, user} ->
                token = Phoenix.Token.sign(Endpoint, "user_auth", user.id)
                _ = ThousandIsland.Socket.send(socket, "registered \n")
                _ = ThousandIsland.Socket.send(socket, ("token:" <> token <> "\n"))
                state
              {:error, _} ->
                _ = ThousandIsland.Socket.send(socket, "register failed\n")
                state
            end
          _ ->
            _ = ThousandIsland.Socket.send(socket, "Usage: register <user> <pass> <display>\n")
            state
        end

      true ->
        state
    end
  end

  defp validate_token(_token), do: true
end
