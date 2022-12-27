defmodule Mix.Tasks.LD.Gen.Resource do
  @shortdoc "Generates resources"

  use Mix.Task
  import Mix.Generator

  @switches [resource: :string]

  @impl true
  def run(argv) do
    {opts, argv} = OptionParser.parse!(argv, strict: @switches)

    case argv do
      [] ->
        Mix.raise("Expected PATH to be given, please use \"mix ld.gen.resource PATH\"")

      [path | _] ->
        unless path == "." do
          check_directory_existence!(path)
          File.mkdir_p!(path)
        end

        File.cd!(path, fn ->
          res = opts[:resource] || "activity"
          mod = Macro.camelize(res)
          generate(mod, path, opts)
        end)
    end
  end

  defp generate(mod, path, opts) do
    assigns = [
      mod: mod,
      version: get_version(System.version())
    ]

    mod_filename = Macro.underscore(mod)

    create_directory("lib")
    create_file("lib/#{mod_filename}.ex", lib_template(assigns))

    # create_directory("test")
    # create_file("test/test_helper.exs", test_helper_template(assigns))
    # create_file("test/#{mod_filename}_test.exs", test_template(assigns))

    """
    Resource created successfully.
    """
    |> String.trim_trailing()
    |> Mix.shell().info()
  end

  defp check_directory_existence!(path) do
    msg = "The directory #{inspect(path)} already exists. Are you sure you want to continue?"

    if File.dir?(path) and not Mix.shell().yes?(msg) do
      Mix.raise("Please select another directory for installation")
    end
  end

  defp get_version(version) do
    {:ok, version} = Version.parse(version)

    "#{version.major}.#{version.minor}" <>
      case version.pre do
        [h | _] -> "-#{h}"
        [] -> ""
      end
  end

  embed_template(:lib, """
  defmodule Fedi.ActivityStreams.Type.<%= @mod %> do
    @moduledoc \"""
    Documentation for `<%= @mod %>`.
    \"""
    @doc \"""
    Hello world.
    ## Examples
        iex> <%= @mod %>.hello()
        :world
    \"""
    def hello do
      :world
    end
  end
  """)
end
