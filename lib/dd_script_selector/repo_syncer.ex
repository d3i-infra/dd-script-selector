defmodule DdScriptSelector.RepoSyncer do
  @moduledoc """
  Clones the data-donation-task repository and installs its pnpm dependencies.

  On startup it immediately performs a sync, then repeats every 24 hours.
  Each run removes the existing clone directory (if present) before re-cloning,
  then runs `pnpm install --frozen-lockfile` to install JavaScript dependencies.

  Requires `git` and `pnpm` to be available on the host.
  """

  use GenServer
  require Logger

  @repo_url "https://github.com/d3i-infra/data-donation-task"
  @target_dir Path.join(System.tmp_dir!(), "data-donation-task")
  @interval :timer.hours(24)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    {name, _opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @doc """
  Returns the local directory where the repository is cloned.
  """
  def clone_dir, do: @target_dir

  @doc """
  Returns a path inside the cloned repository for a given subdirectory.
  """
  def path(subdir), do: Path.join(@target_dir, subdir)

  @doc """
  Returns the platforms directory inside the cloned repository.
  """
  def platforms_dir, do: Path.join(@target_dir, "packages/python/port/platforms")

  @doc """
  Clones `repo_url` into `target_dir`, removing any prior clone first.
  Returns `:ok` on success or `{:error, output}` on failure.
  """
  def sync(repo_url, target_dir) do
    File.mkdir_p!(Path.dirname(target_dir))

    if File.exists?(target_dir), do: File.rm_rf!(target_dir)

    Logger.info("RepoSyncer: cloning #{repo_url} → #{target_dir}")

    case System.cmd("git", ["clone", repo_url, target_dir], stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("RepoSyncer: clone successful")
        :ok

      {output, exit_code} ->
        Logger.error("RepoSyncer: clone failed (exit #{exit_code})\n#{output}")
        {:error, output}
    end
  end

  @doc """
  Clones the data-donation-task repository and installs pnpm dependencies.
  Returns `:ok` on success or `{:error, output}` on the first failing step.
  """
  def sync do
    with :ok <- sync(@repo_url, @target_dir) do
      install_deps(@target_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init([]) do
    send(self(), :sync)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync, state) do
    sync()
    Process.send_after(self(), :sync, @interval)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp install_deps(target_dir) do
    Logger.info("RepoSyncer: installing pnpm dependencies in #{target_dir}")

    case System.cmd("pnpm", ["install", "--frozen-lockfile"],
           cd: target_dir,
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        Logger.info("RepoSyncer: pnpm install successful")
        :ok

      {output, exit_code} ->
        Logger.error("RepoSyncer: pnpm install failed (exit #{exit_code})\n#{output}")
        {:error, output}
    end
  end
end
