defmodule MatchMaker.Room do
  @callback start_link(String.t) :: {:ok, pid}
  @callback handle_join(pid, pid) :: {:ok, :joined, any} | :error
  # TODO: handle_leave(pid, pid) :: :ok
  @callback close(pid) :: :ok
end