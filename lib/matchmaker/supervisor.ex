defmodule Matchmaker.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    # TODO: accept or read pool size from config
    config = Application.get_env(:matchmaker, __MODULE__)
    max_subscribers = config[:max_subscribers] || 4
    room_adapter = config[:room_adapter] || nil
    children = [
      worker(Matchmaker.RoomServer, [max_subscribers, room_adapter, [name: Matchmaker.RoomServer]])
    ]

    supervise(children, strategy: :one_for_one)
  end
end