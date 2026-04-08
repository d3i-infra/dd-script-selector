defmodule DdScriptSelector.RepoSyncerTest do
  use ExUnit.Case, async: true

  alias DdScriptSelector.RepoSyncer

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Creates a minimal bare git repo and returns its path.
  # The repo has one commit so cloning it produces a valid working tree.
  defp make_bare_repo do
    base = Path.join(System.tmp_dir!(), "repo_syncer_src_#{System.unique_integer([:positive])}")
    bare = Path.join(base, "source.git")
    work = Path.join(base, "work")
    File.mkdir_p!(work)

    for {cmd, args} <- [
          {"git", ["init", work]},
          {"git", ["-C", work, "config", "user.email", "test@example.com"]},
          {"git", ["-C", work, "config", "user.name", "Test"]},
          {"git", ["-C", work, "commit", "--allow-empty", "-m", "init"]}
        ] do
      {_, 0} = System.cmd(cmd, args, stderr_to_stdout: true)
    end

    {_, 0} = System.cmd("git", ["clone", "--bare", work, bare], stderr_to_stdout: true)

    on_exit(fn -> File.rm_rf!(base) end)

    bare
  end

  defp tmp_clone_dir do
    path = Path.join(System.tmp_dir!(), "repo_syncer_clone_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end

  # ---------------------------------------------------------------------------
  # sync/2
  # ---------------------------------------------------------------------------

  describe "sync/2" do
    test "clones a repository into the target directory" do
      source = make_bare_repo()
      target = tmp_clone_dir()

      assert :ok = RepoSyncer.sync(source, target)
      assert File.dir?(target)
      assert File.exists?(Path.join(target, ".git"))
    end

    test "overwrites an existing clone directory" do
      source = make_bare_repo()
      target = tmp_clone_dir()

      assert :ok = RepoSyncer.sync(source, target)
      assert :ok = RepoSyncer.sync(source, target)

      assert File.dir?(target)
    end

    test "returns an error tuple when the repo URL is invalid" do
      target = tmp_clone_dir()

      assert {:error, reason} = RepoSyncer.sync("/nonexistent/repo.git", target)
      assert is_binary(reason)
    end

    test "leaves no clone directory behind on failure" do
      target = tmp_clone_dir()

      RepoSyncer.sync("/nonexistent/repo.git", target)

      refute File.exists?(target)
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "GenServer" do
    test "starts successfully, performs initial sync, and stays alive" do
      source = make_bare_repo()
      target = tmp_clone_dir()
      name = :"repo_syncer_#{System.unique_integer([:positive])}"

      pid =
        start_supervised!(
          {RepoSyncer, [name: name, repo_url: source, target_dir: target]}
        )

      # Give the initial :sync message time to be processed
      Process.sleep(500)

      assert Process.alive?(pid)
      assert File.dir?(target)
    end
  end
end
