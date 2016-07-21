defmodule Matchmaker.RoomServer do
  use GenServer
  alias Matchmaker.RoomInfo
  require Logger
  
  @max_subscribers Application.get_env(:matchmaker, :max_subscribers)
  @room_mod Application.get_env(:matchmaker, :room_mod)

  # --- client api ---

  def start_link(opts \\ []) do
    Logger.info "Matchmaker server starting"
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def match(server) do # TODO: add args/ match criteria here??
    GenServer.call(server, :match)
  end

  def join(server, pid, room_id) do
    GenServer.call(server, {:join, pid, room_id})
  end

  def get_rooom_info(server, room_id) do
    GenServer.call(server, {:get_room_info, room_id})
  end

  def change_max(server, max) do
    GenServer.call(server, {:change_max, max})
  end

  def change_room_mod(server, mod) do
    GenServer.call(server, {:change_room_mod, mod})
  end

  # --- server callbacks ---

  @doc """
    Set process to trap exits.
    This way we can catch channel crashes
    but also crash the channels if the matchmaking server
    goes down, so we don't have to worry about storing refs, remonitoring,
    tracking refs by matchmaking server, or potentially remonitoring
    dead processes.
  """
  def init(:ok) do
    Process.flag(:trap_exit, true)
    {:ok, %{
      :channels => Map.new(), # channels map pid of channel to room_id
      :rooms => Map.new(), # rooms map room_id to %RoomInfo{}
      :max_subscribers => @max_subscribers,
      :room_mod => @room_mod}
    }
  end

  @doc """
    Matches caller to next available room, or
    creates a new room if none are available.
  """
  def handle_call(:match, _from, state) do
    case get_next_available_room(state) do
      {:ok, room_id} -> {:reply, {:ok, room_id}, state}
      :error -> 
        {:ok, room_id} = gen_new_room_id()
        {:ok, room_pid} = state.room_mod.start_link(room_id)
        Process.link(room_pid)
        {:reply, room_id, state |> put_room(room_id, room_pid)}
    end
  end

  @doc """
    Gets room info.
  """
  def handle_call({:get_room_info, room_id}, _from, state) do
    case Map.fetch(state.rooms, room_id) do
      {:ok, info} -> {:reply, {:ok, info}, state}
      :error -> {:reply, :error, state}
    end
  end

  @doc """
    Joins a room.
  """
  def handle_call({:join, pid, room_id}, _from, state) do
    Process.link(pid) # link so we trap exit -> consider monitoring, but remonitoring seems problematic...
    case Map.fetch(state.rooms, room_id) do
      :error -> {:reply, {:error, :bad_room}, state}
      {:ok, room_info} -> do_join_room(state, pid, room_info)
    end
  end

  @doc """
    Changes max subscribers per room.
  """
  def handle_call({:change_max, max}, _from, state) do
    {:reply, :ok, Map.put(state, :max_subscribers, max)}
  end

  @doc """
    Changes callback room module.
  """
  def handle_call({:change_room_mod, mod}, _from, state) do
    {:reply, :ok, Map.put(state, :room_mod, mod)}
  end
  
  @doc """
    Catch exit signals and remove channel.
  """
  def handle_info({:EXIT, pid, _reason}, state) do
    # any way to avoid trying to find room pids for no reason?
    # TODO: if room_id is found, get room, tell it that this pid has left
    # it will be up to room to tell channel to broadcast
    case Map.fetch(state.channels, pid) do
      {:ok, room_id} -> {:noreply, state |> drop_channel(pid) |> decrement_room(room_id)}
      :error -> {:noreply, state}
    end
  end

  @doc """
    Ignores random messags.
  """
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---
  
  defp get_next_available_room(state) do
    # TODO: store in / retrieve from ets?
    rooms = 
      state
      |> filter_max_subs()
      |> Enum.map(fn {room_id, _info} -> room_id end)
    case rooms do 
      [] -> :error
      [h|_t] -> {:ok, h}
    end
  end

  defp filter_max_subs(state) do
    state.rooms 
    |> Enum.filter(fn {_id, room_info} -> 
      room_info.member_count < state.max_subscribers 
    end)
  end

  defp gen_new_room_id() do
    {:ok, UUID.uuid4(:weak)}
  end

  defp put_channel(state, pid, room_id) do
    %{state | channels: Map.put(state.channels, pid, room_id)}
  end

  defp drop_channel(state, pid) do
    %{state | channels: Map.delete(state.channels, pid)}
  end

  defp put_room(state, room_id, room_pid) do
    room = %RoomInfo{
      :room_id => room_id,
      :room_pid => room_pid,
      :created_at => DateTime.utc_now()
    }
    %{state | rooms: Map.put(state.rooms, room_id, room)}
  end

  defp do_join_room(state, pid, room_info) do
    cond do
      room_info.member_count > state.max_subscribers -> {:reply, {:error, :too_crowded}, state}
      true ->
        case state.room_mod.handle_join(room_info.room_pid, pid) do
          {:ok, :joined, return_arg} ->
            s = state |> put_channel(pid, room_info.room_id) |> increment_room(room_info.room_id)
            {:reply, {:ok, room_info.room_pid, return_arg}, s}
          :error -> {:reply, {:error, :unable_to_join}, state}
        end
    end
  end

  defp increment_room(state, room_id) do
    case Map.fetch(state.rooms, room_id) do
      {:ok, room_info} -> 
        room = room_info |> RoomInfo.update_count(room_info.member_count + 1)
        %{state | rooms: Map.put(state.rooms, room_id, room)}
      :error -> state
    end
  end

  defp decrement_room(state, room_id) do
    case Map.fetch(state.rooms, room_id) do
      :error -> state
      {:ok, room_info} ->
        case room_info.member_count do
          1 ->  
            %{state | rooms: Map.delete(state.rooms, room_id)} # don't maintain empty rooms    
            room_info.room_pid |> state.room_mod.close()
          ct ->
            room = RoomInfo.update_count(room_info, ct - 1)
            %{state | rooms: Map.put(state.rooms, room_id, room)}
        end
    end
  end
end