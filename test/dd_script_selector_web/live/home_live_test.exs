defmodule DdScriptSelectorWeb.HomeLiveTest do
  use DdScriptSelectorWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders hero headline", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "h1", "Build your data donation script")
  end

  test "renders get started button", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#hero a[href='/form']")
  end

  test "renders configure step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#step-configure")
  end

  test "renders download step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#step-download")
  end
end
