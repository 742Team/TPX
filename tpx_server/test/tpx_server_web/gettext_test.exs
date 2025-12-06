defmodule TpxServerWeb.GettextTest do
  use ExUnit.Case, async: true

  test "lgettext and lngettext" do
    assert {:default, "hello"} = TpxServerWeb.Gettext.lgettext("en", "default", "hello", %{})
    assert {:default, _} = TpxServerWeb.Gettext.lngettext("en", "default", "one", "many", 2, %{})
  end
end
