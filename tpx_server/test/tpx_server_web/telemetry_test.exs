defmodule TpxServerWeb.TelemetryTest do
  use ExUnit.Case, async: true

  test "metrics returns list" do
    ms = TpxServerWeb.Telemetry.metrics()
    assert is_list(ms) and length(ms) > 0
  end
end
