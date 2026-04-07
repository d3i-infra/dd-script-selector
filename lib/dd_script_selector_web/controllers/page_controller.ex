defmodule DdScriptSelectorWeb.PageController do
  use DdScriptSelectorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
