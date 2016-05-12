defmodule Exjsonrpc.Mixfile do
  use Mix.Project

  def project do
    [app: :exjsonrpc,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:exjsx, github: "talentdeficit/exjsx"}]
  end
end
