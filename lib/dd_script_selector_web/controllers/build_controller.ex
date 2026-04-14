defmodule DdScriptSelectorWeb.BuildController do
  use DdScriptSelectorWeb, :controller

  @builder_base "http://localhost:8000"

  def download(conn, %{"id" => id}) do
    case Req.get(@builder_base <> "/download/#{id}",
           [decode_body: false, retry: false] ++ builder_req_opts()
         ) do
      {:ok, %{status: 200, body: body}} ->
        conn
        |> put_resp_header("content-type", "application/zip")
        |> put_resp_header("content-disposition", ~s|attachment; filename="build.zip"|)
        |> send_resp(200, body)

      _ ->
        send_resp(conn, 502, "Build not available")
    end
  end

  defp builder_req_opts, do: Application.get_env(:dd_script_selector, :builder_req_opts, [])
end
