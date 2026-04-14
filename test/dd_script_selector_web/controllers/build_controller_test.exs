defmodule DdScriptSelectorWeb.BuildControllerTest do
  use DdScriptSelectorWeb.ConnCase, async: false

  setup do
    Application.put_env(:dd_script_selector, :builder_req_opts,
      plug: {Req.Test, :builder_api}
    )

    on_exit(fn -> Application.delete_env(:dd_script_selector, :builder_req_opts) end)
    :ok
  end

  test "GET /builds/:id/download proxies zip from builder API", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/zip")
      |> Plug.Conn.send_resp(200, "fake-zip-bytes")
    end)

    conn = get(conn, "/builds/some-uuid/download")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["application/zip"]
    assert get_resp_header(conn, "content-disposition") == [~s|attachment; filename="build.zip"|]
    assert conn.resp_body == "fake-zip-bytes"
  end

  test "GET /builds/:id/download returns 502 when builder API fails", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      Plug.Conn.send_resp(conn, 500, "error")
    end)

    conn = get(conn, "/builds/some-uuid/download")
    assert conn.status == 502
  end
end
