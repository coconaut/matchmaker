defmodule MatchMaker.Room do
  @callback start_link(String.t) :: {:ok, pid}
  @callback join(pid, pid) :: {:ok, :joined} | :error
  @callback close(pid) :: :ok
end