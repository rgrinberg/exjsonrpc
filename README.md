Exjsonrpc
=========

A transport agnostic client/server jsonrpc 2.0 library for elixir.

# Summary

This library provides:

* jsonrpc 2.0 request/response serializers/deserializers

* A relatively boilerplate free method of exposing functions as jsonrpc
services

This library does not provide:

* Transport mechanism for your jsonrpc service. I.e. you will have to
expose the service over a socket, http, etc. yourself.

# Hello Exjsonrpc

Given some simple genserver:

```
defmodule TestServer do
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
  def handle_call(:stop, _from, s) do
    {:stop, :normal, s}
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
  def stop(pid) do
    GenServer.call(pid, :stop)
  end
end
```

```
# we specify the server we'd like to expose and the methods it exposes
rpc = %{
  # expose request and notification separately
  "add" => {fn([x]) -> GenServer.call(pid, {:add, x}) end,
            fn([x]) -> GenServer.cast(pid, {:add, x}) -> end},
  # use GenServer.call for both
  "reset" => fn([]) -> GenServer.call(pid, :reset)
}
{:ok, jsonrpc} = Exjsonrpc.Server.start_link(rpc)
request = Exjsonrpc.Client.request method: :add, params: [5]
resp = GenServer.call(jsonrpc, request)
IO.puts "Json response: #{resp}"
```
