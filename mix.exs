defmodule VideoStream.MixProject do
  use Mix.Project

  def project do
    [
      app: :video_stream,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers() ++ [:pip_deps],
      pip_deps: pip_deps()
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
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:req, "~> 0.3"},
      {:fast_xml, "~> 1.1"},
      # {:python_ex, git: "git@github.com:OdielDomanie/python_ex.git"}
      {:python_ex, path: "../python_ex"}
    ]
  end

  defp pip_deps do
    [
      "yt-dlp"
    ]
  end
end
