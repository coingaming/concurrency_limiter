defmodule ConcurrencyLimiter.MixProject do
  use Mix.Project

  @version "1.0.1"
  @url "https://github.com/coingaming/concurrency_limiter"

  def project do
    [
      app: :concurrency_limiter,
      version: @version,
      elixir: "~> 1.7",
      name: "ConcurrencyLimiter",
      description: "Lightweight library for restricting concurrency",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_pool, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: [:docs]}
    ]
  end

  defp docs do
    [
      main: "ConcurrencyLimiter",
      source_ref: "v#{@version}",
      source_url: @url
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      maintainers: ["v0idpwn"],
      links: %{"GitHub" => @url}
    }
  end
end
