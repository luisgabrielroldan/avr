defmodule AVR.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :avr,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package(),
      source_url: "https://github.com/luisgabrielroldan/avr",
      dialyzer: [
        flags: [:error_handling, :race_conditions, :underspecs]
      ]
    ]
  end

  defp description do
    """
    AVR is a library to upload a firmware into AVR microcontrollers
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    %{
      files: ["lib", "mix.exs", "README.md"],
      maintainers: [
        "Gabriel Roldan"
      ],
      licenses: ["Apache License 2.0"],
      links: %{
        "GitHub" => "https://github.com/luisgabrielroldan/avr"
      }
    }
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/luisgabrielroldan/avr",
      extras: [
        "README.md"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_uart, "~> 1.4.1"},
      {:circuits_gpio, "~> 0.4"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:earmark, "~> 1.3", only: :dev, runtime: false},
      {:dialyxir, "1.0.0-rc.7", only: :dev, runtime: false}
    ]
  end
end
