defmodule MatchMaker.Room do
  @callback start_link(String.t) :: {:ok, pid}
  @callback join(pid, pid) :: {:ok, :joined, any} | :error
  # TODO: leave(pid, pid) :: :ok
  @callback close(pid) :: :ok
end