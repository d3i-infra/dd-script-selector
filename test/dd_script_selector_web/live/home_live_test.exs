defmodule DdScriptSelectorWeb.HomeLiveTest do
  use DdScriptSelectorWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders hero headline", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "h1", "Configure a data donation script")
  end

  test "renders get started button", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#hero a[href='/select']")
  end

  test "renders steps section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#steps")
  end

  test "renders platforms section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#platforms")
  end
end
