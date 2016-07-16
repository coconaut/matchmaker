defmodule Matchmaker.Server do
	use GenServer
	require Logger

	# TODO: make umbrella app, throw in git separately, add as deps to real phoenix proj

	# NOTE: channels use different channel_pid per topic,
	# even when created from same socket
	# this means we can monitor once through join, one channel per topic, etc.

	# TODO: make poolable, ets, recovery? or crash sockets, either way
	# actually -> Process trap exit may be the way to go, since we'll
	# for the sockets to rejoin (consider for yowo as well instead of ets foldl)
	# and, they could rejoin a diff matchmaker and it wouldn't matter

	# TODO: updates to functions, max subs, etc.
    
	@max_subscribers Application.get_env(:matchmaker, :max_subscribers)

	# --- client api ---

	def start_link(opts \\ []) do
		Logger.info "Matchmaker server starting"
		GenServer.start_link(__MODULE__, :ok, opts)
	end

	def match(server) do # TODO: add args/ match criteria here??
		GenServer.call(server, :match)
	end

	def match(server, args) do
		GenServer.call(server,{:match, args})
	end

	def join(server, pid, room_id) do
		GenServer.call(server, {:join, pid, room_id})
	end

	def change_max(server, max) do
		GenServer.call(server, {:change_max, max})
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
			:channels => Map.new(), 
			:rooms => Map.new(), 
			:max_subscribers => @max_subscribers}
		}
	end

	def handle_call(:match, _from, state) do
		room_id = get_next_available_room(state)
		Logger.debug "Match to room #{room_id}"
		{:reply, {:ok, room_id}, state}
	end

	def handle_call({:match, args}, _from, state) do
		# TODO: send args through matchmaking function?
		room_id = get_next_available_room(state)
		Logger.debug "Match to room #{room_id}"
		{:reply, {:ok, room_id, state}}
	end

	@doc """
		Joins a room.
	"""
	def handle_call({:join, pid, room_id}, _from, state) do
		Process.link(pid) # link so we trap exit
		# TODO: track time?
		# TODO: check room_id again, make sure still < 4, otherwise {:error}, so client can re-match
		
		s = state |> put_channel(room_id, pid) |> increment_room(room_id)
		{:reply, {:ok, pid}, s}
	end

	def handle_call({:change_max, max}, _from, state) do
		{:reply, :ok, Map.put(state, :max_subscribers, max)}
	end
	
	@doc """
		Catch exit signals and remove channel.
	"""
	def handle_info({:EXIT, pid, _reason}, state) do
        case Map.fetch(state.channels, pid) do
          {:ok, room_id} -> {:noreply, state |> drop_channel(pid) |> decrement_room(room_id)}
          :error -> {:noreply, state}
        end
    end

	def handle_info(_msg, state) do
		{:noreply, state}
	end

	defp get_next_available_room(state) do
		# TODO: store in / retrieve from ets?
		rooms = 
			state
			|> filter_max_subs()
			|> Enum.map(fn {room_id, _ct} -> room_id end)
		case rooms do 
			[] -> gen_new_room()
			[h|_t] -> h
		end
	end

	defp get_next_available_room(state, args) do
		# TODO: if state has filter funcs or precedence funcs for matches, 
		# then use recursively (w/ prev winner, etc.)
		# also factor wait time and room count
		get_next_available_room(state)
	end

	defp filter_max_subs(state) do
		state.rooms |> Enum.filter(fn {_room_id, ct} -> ct < state.max_subscribers end)
	end

	defp gen_new_room() do
		UUID.uuid4(:weak)
	end

	defp put_channel(state, room_id, pid) do
		%{state | channels: Map.put(state.channels, pid, room_id)}
	end

	defp drop_channel(state, pid) do
		%{state | channels: Map.delete(state.channels, pid)}
	end

	defp increment_room(state, room_id) do
		count = 
			case Map.fetch(state.rooms, room_id) do
				{:ok, ct} -> ct + 1
				:error -> 1
			end
		%{state | rooms: Map.put(state.rooms, room_id, count)}
	end

	defp decrement_room(state, room_id) do
		case Map.fetch(state.rooms, room_id) do
			{:ok, 1} -> %{state | rooms: Map.delete(state.rooms, room_id)} # don't maintain empty rooms
			{:ok, ct} -> %{state | rooms: Map.put(state.rooms, room_id, ct - 1)}
			:error -> state
		end
	end

	# def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
	# 	case Map.fetch(state.channels, ref) do
	# 		{:ok, room_id} -> {:noreply, state |> drop_channel(ref) |> decrement_room(room_id)}
	# 		:error -> {:noreply, state}
	# 	end
	# end

end