defmodule Matchmaker.RoomInfo do
  defstruct [
    room_id: "",
    room_pid: nil,
    member_count: 0,
    locked?: false,
    created_at: nil,
    last_joined_at: nil
  ]

  def update_count(room, ct) do
    Map.put(room, :member_count, ct)
  end

  def update_last_joined(room) do
    Map.put(room, :last_joined_at, DateTime.utc_now())
  end

  def lock_room(room) do
    Map.put(room, :locked?, true)
  end
end