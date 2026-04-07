defmodule DdScriptSelector.Repo do
  use Ecto.Repo,
    otp_app: :dd_script_selector,
    adapter: Ecto.Adapters.Postgres
end
