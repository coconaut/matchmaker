defmodule Matchmaker.Room do
  @callback start_link(String.t, Matchmaker.RoomServer.t) :: {:ok, pid}
  @callback join(pid | atom, pid, any) :: {:ok, :joined, any} | :error
  @callback leave(pid, pid) :: :ok
  @callback close(pid) :: :ok
end