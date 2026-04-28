defmodule DdScriptSelector.PyDocExtractor do
  @moduledoc """
  Fetches platform configuration from the dd-script-builder service.
  """

  @doc """
  Calls `GET <builder_base>/config?platform=<platform_name>` and returns
  `{:ok, config_map}` or `{:error, reason}`.
  """
  def extract(platform_name) do
    builder_base = Application.fetch_env!(:dd_script_selector, :builder_base)
    url = "#{builder_base}/config"

    case Req.get(url, params: [platform: platform_name]) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
