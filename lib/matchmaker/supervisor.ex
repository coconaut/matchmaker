defmodule Matchmaker.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    # TODO: accept or read pool size from config
    children = [
      worker(Matchmaker.RoomServer, [[name: Matchmaker.RoomServer]])
    ]

    supervise(children, strategy: :one_for_one)
  end
end