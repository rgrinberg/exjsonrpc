defmodule ExjsonrpcTest do
  defmodule TestServer do
    @moduledoc """
    A simple server we'll expose as jsonrpc for testing purposes. It supports
    2 operations:
    1) add n -> add n to the current number
    2) reset n -> reset the counter back to 0
    """
    use GenServer
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, 0, opts)
    end
    def handle_call({:add, x}, _from, s) do
      new_state = s + x
      {:reply, new_state, new_state}
    end
    def handle_call(:reset, _from, _s) do
      {:reply, 0, 0}
    end
    def handle_cast(req, s) do
      {_, _, s } = handle_call(req, nil, s)
      {:noreply, s}
    end
    def current_state(pid) do
      GenServer.call(pid, {:add, 0})
    end
    def add(pid, n) do
      GenServer.call(pid, {:add, n})
    end
    def reset(pid) do
      GenServer.call(pid, :reset)
    end
  end
  use ExUnit.Case

  test "TestServer semi works" do
    {:ok, pid} = TestServer.start_link
    assert TestServer.current_state(pid) == 0
    TestServer.add(pid, 3)
    TestServer.add(pid, 2)
    assert TestServer.current_state(pid) == 5
    Process.exit pid, :kill
  end

  test "basic json request works" do
    {:ok, pid} = TestServer.start_link
    rpc = %{
      "add" => fn([x]) -> TestServer.add(pid, x) end,
      "reset" => fn(_) -> TestServer.reset(pid) end
    }
    {:ok, rpc} = Exjsonrpc.Server.start_link(rpc)
    req = Exjsonrpc.Client.request method: :add, params: [5]
    {:ok, resp} = GenServer.call(rpc, req) |> Exjsonrpc.Client.response
    assert resp.result == 5
    req = Exjsonrpc.Client.notification method: :add, params: [4]
    :ok = GenServer.call(rpc, req)
    assert TestServer.current_state(pid) == 9
    Process.exit pid, :kill
    Process.exit rpc, :kill
  end

  # test "readme" do
  #   rpc = %{
  #     # expose request and notification separately
  #     "add" => {fn([x]) -> GenServer.call(pid, {:add, x}) end,
  #               fn([x]) -> GenServer.cast(pid, {:add, x}) end},
  #     # use GenServer.call for both
  #     "reset" => fn([]) -> GenServer.call(pid, :reset) end
  #   }
  #   {:ok, jsonrpc} = Exjsonrpc.Server.start_link(rpc)
  #   request = Exjsonrpc.Client.request method: :add, params: [5]
  #   _resp = GenServer.call(jsonrpc, request)
  #   Process.exit jsonrpc
  #   assert 1 == 1
  # end
end
