defmodule Exjsonrpc.Mixfile do
  use Mix.Project

  def project do
    [app: :exjsonrpc,
     version: "0.0.1",
     elixir: "~> 0.14.0-dev",
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:jsex, github: "talentdeficit/jsex"}]
  end
end
