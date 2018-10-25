defmodule Passport.Mixfile do
  use Mix.Project

  defp pathname_VERSION() do
    Path.expand("VERSION", Path.dirname(__ENV__.file))
  end

  defp read_VERSION(), do: File.read!(pathname_VERSION()) |> String.trim()

  def project do
    [
      app: :passport,
      elixirc_paths: elixirc_paths(Mix.env),
      version: read_VERSION(),
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      compilers: if Mix.env == :test do
        [:phoenix, :gettext] ++ Mix.compilers
      else
        Mix.compilers
      end,
      deps: deps()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Phoenix for testing
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2", only: [:test]},
      {:phoenix_html, "~> 2.10", only: [:test]},
      {:gettext, "~> 0.11", only: [:test]},
      {:cowboy, "~> 1.0", only: [:test]},
      {:postgrex, ">= 0.0.0", only: [:test]},
      #
      {:bcrypt_elixir, "~> 1.0"},
      {:comeonin, "~> 4.0"},
      {:pot, "~> 0.9"},
      {:ecto, "~> 2.2"},
      {:poison, "~> 2.0 or ~> 3.0"},
      #
      {:ex_machina, "~> 2.0", git: "https://github.com/thoughtbot/ex_machina", only: :test},
    ]
  end
end
