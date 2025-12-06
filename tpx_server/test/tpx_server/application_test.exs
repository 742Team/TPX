defmodule TpxServer.ApplicationTest do
  use ExUnit.Case, async: true

  test "config_change returns :ok" do
    assert :ok == TpxServer.Application.config_change(%{}, %{}, [])
  end
end
