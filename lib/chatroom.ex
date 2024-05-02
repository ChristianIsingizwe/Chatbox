defmodule ChatRoom do
  defmodule RoomAgent do
    use Agent

    def start_link do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def add_message(message) do
      Agent.update(__MODULE__, fn state ->
        Map.put(state, :messages, [message | Map.get(state, :messages, [])])
      end)
    end

    def get_messages do
      get_state() |> Map.get(:messages, [])
    end

    def get_state() do
      Agent.get(__MODULE__, & &1)
    end

    def check_username_available?(username, registered_usernames) do
      !Map.has_key?(registered_usernames, username)
    end

    def store_username(username, pid, registered_usernames) do
      Map.put(registered_usernames, username, pid)
    end

    def remove_username(username, registered_usernames) do
      Map.delete(registered_usernames, username)
    end

    def get_user_pid(username, registered_usernames) do
      Map.get(registered_usernames, username)
    end

    # Define the update function to update the agent's state
    def update(state) do
      Agent.update(__MODULE__, fn _ -> state end)
    end
  end

  def start do
    RoomAgent.start_link()
  end

  def join(username) do
    registered_usernames = RoomAgent.get_state()

    if RoomAgent.check_username_available?(username, registered_usernames) do
      user = Task.async(fn -> user_loop(username) end)
      Process.link(user.pid)
      updated_usernames = RoomAgent.store_username(username, user.pid, registered_usernames)
      # Use the newly defined update function
      RoomAgent.update(updated_usernames)
      {:ok, username}
    else
      {:error, "Username already taken"}
    end

    Process.exit()
  end

  def leave(username) do
    registered_usernames = RoomAgent.get_state()

    case RoomAgent.get_user_pid(username, registered_usernames) do
      nil ->
        {:error, "User not found"}

      pid ->
        Process.exit(pid, :normal)
        updated_usernames = RoomAgent.remove_username(username, registered_usernames)
        # Use the newly defined update function
        RoomAgent.update(updated_usernames)
        :ok
    end
  end

  def send_message(username, message) do
    case RoomAgent.get_user_pid(username, RoomAgent.get_state()) do
      nil ->
        {:error, "You haven't joined the chat room yet."}
      _ ->
        RoomAgent.add_message({username, message})
        {:ok, "Message sent successfully."}
    end
  end

  def get_messages(username) do
    case RoomAgent.get_user_pid(username, RoomAgent.get_state()) do
      nil ->
        {:error, "You haven't joined the chat room yet."}
      _ ->
        RoomAgent.get_messages()
    end
  end

  defp user_loop(username) do
    case RoomAgent.get_user_pid(username, RoomAgent.get_state()) do
      nil ->
        IO.puts("You haven't joined the chat room yet.")
        :ok
      _ ->
        receive do
          {:join, _pid} ->
            IO.puts("#{username} has joined the chat room.")
            user_loop(username)

          {:leave, _pid} ->
            IO.puts("#{username} has left the chat room.")
            :ok

          {from, message} ->
            IO.puts("#{from}: #{message}")
            user_loop(username)
        end
    end
  end
end

children = [
  %{
    id: ChatRoom,
    start: {ChatRoom, :start, []},
    restart: :permanent,
    type: :worker
  }
]

{:ok, pid} = Supervisor.start_link(children, strategy: :one_for_all)

IO.inspect(pid)
