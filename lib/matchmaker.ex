defmodule Matchmaker do
	use Application

	def start(_type, _args) do
		Matchmaker.Supervisor.start_link()
	end
end
