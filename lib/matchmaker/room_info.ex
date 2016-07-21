defmodule Matchmaker.RoomInfo do
  defstruct [
    room_id: "",
    room_pid: nil,
    member_count: 0,
    started?: false,
    created_at: nil,
    last_joined_at: nil
  ]

  def update_count(room, ct) do
    Map.put(room, :member_count, ct)
  end
end