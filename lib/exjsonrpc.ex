defmodule Exjsonrpc.Client do
  defp response_single(map) do
    map = map |> Map.delete :jsonrpc
    case map |> Map.fetch :result do
      :error -> {:error, map}
      {:ok, _} -> {:ok, map}
    end
  end

  def response(resp) do
    case JSEX.decode resp, [{:labels, :atom}] do
      {:error, error} -> {:error, error}
      {:ok, resp} when is_list resp -> resp |> Enum.map &response_single/1
      {:ok, resp} -> response_single(resp)
    end
  end

  def request(method: m, params: p) do
    notification_raw(m, p)
    |> Map.put_new(:id, 123)
    |> JSEX.encode!
  end

  def notification(method: m, params: p) do
    notification_raw(m, p) |> JSEX.encode!
  end

  defp notification_raw(m, p) do
    %{:jsonrpc => "2.0", :method => m, :params => p}
  end
end

defmodule Exjsonrpc.Server do
  use GenServer
  defstruct methods: %{}, debug: false, exception_mapper: :default

  defp ex_error do
    %{ :code => -32603, :message => "Internal Server Error" }
  end

  defp any_call(method, params) when is_function method do
    try do
      method.(params)
    rescue
      ex -> {:exception, ex}
    end
  end

  defp any_call({:spawn, method}, params) do
    any_call(method, params) 
  end

  defp any_call({method, _}, params) do
    any_call(method, params)
  end

  defp any_cast({:spawn, method}, params) when is_function method do
    spawn fn () -> method.(params) end
  end

  defp any_cast(method, params) when is_function method do
    method.(params)
  end

  defp any_cast({_, method}, params) when is_function method do
    any_cast(method, params)
  end

  def make_error(res) do
    res
    |> Map.put_new :code, -32603
    |> Map.put_new :message, "Error processing request"
  end

  def call(rpc, request) do
    method = rpc.methods[request.method]
    case Map.fetch request, :id  do
      :error -> any_cast rpc.methods[request.method], request.params
      {:ok, id} ->
        resp = case any_call(rpc.methods[request.method], request.params) do
          {:call, params} -> call(rpc, %{request | :params => params})
          {:error, res} -> make_error(res)
          {:exception, res} ->
            case rpc.exception_mapper do
              :default -> ex_error
              f -> f.(request.method, request.params, res)
            end
          {:ok, res} -> %{result: res}
          res -> %{result: res}
        end
        resp
        |> Map.put_new(:jsonrpc, "2.0")
        |> Map.put_new(:id, id)
    end
  end


  defp has_keys?(_, []) do
    true
  end

  defp has_keys?(map, [k | ks]) do
    if map |> Map.has_key? k do
      has_keys?(map, ks)
    else
      false
    end
  end

  defp jsoncall_single(rpc, request) do
    if not (Map.has_key? rpc.methods, request.method) do
      %{:code => -32601,
        :message => "Method not found",
        :jsnorpc => "2.0"}
    else
      if has_keys?(request, [:method, :params, :jsonrpc]) do
        call(rpc, request)
      else
        %{:jsonrpc => "2.0",
          :message => "Invalid Request",
          :code => -32600 }
      end
    end
  end

  defp jsoncall(rpc, request) when is_list request do
    request |> Enum.map fn(r) -> jsoncall_single(rpc, r) end
  end

  defp jsoncall(rpc, request) do
    jsoncall_single(rpc, request)
  end

  def start_link(methods, debug \\ False, exception_mapper \\ [], opts\\[]) do
    rpc = %Exjsonrpc.Server{
      methods: methods,
      debug: debug,
      exception_mapper: exception_mapper
    }
    GenServer.start_link(__MODULE__, rpc, opts)
  end

  def handle_call(req, _from, rpc) do
    resp = case JSEX.decode req, [{:labels, :atom}] do
      :error ->
        %{:code => -32700, :message => "Parse error", :jsonrpc => "2.0"}
        {:ok, req} -> jsoncall(rpc, req)
    end
    if is_list(resp) or is_map(resp) do
      {:reply, JSEX.encode!(resp), rpc}
    else
      {:reply, :ok, rpc}
    end
  end

  def handle_cast(req, rpc) do
    case JSEX.decode req, [{:labels, :atom}] do
      :error -> :ok
      {:ok, req} -> jsoncall(rpc, req)
    end
    {:noreply, rpc}
  end
end
