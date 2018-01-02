defmodule Mix.Tasks.Passport.Init do
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Generator
  import Mix.Ecto

  def run(args) do
    no_umbrella!("passport.init")
    repos = parse_repo(args)

    Enum.each repos, fn repo ->
      case OptionParser.parse(args) do
        {_opts, [name, table_name], _} ->
          ensure_repo(repo, args)
          path = migrations_path(repo)
          model_name = String.replace(underscore(name), "/", "_")
          file = Path.join(path, "#{timestamp()}_add_passport_fields_to_#{model_name}.exs")
          create_directory path

          model = Module.concat([name])
          change =
            [
              "    alter table(:#{table_name}) do",
              Enum.map(Passport.migration_fields(model), fn line ->
                "      " <> line
              end),
              "    end",
              "",
              Enum.map(Passport.migration_indices(model), fn line ->
                "    " <> String.replace(line, ~r/<users>/, ":#{table_name}")
              end)
            ]
            |> List.flatten()
            |> Enum.join("\n")

          migration_model_name = String.replace(camelize(name), ".", "")
          mod = Module.concat([repo, Migrations, "AddPassportFieldsTo#{migration_model_name}"])
          assigns = [mod: mod, change: change]
          create_file file, migration_template(assigns)

          if open?(file) and Mix.shell.yes?("Do you want to run this migration?") do
            Mix.Task.run "ecto.migrate", [repo]
          end
        {_, _, _} ->
          Mix.raise "expected passport.init to receive the model name, " <>
                    "got: #{inspect Enum.join(args, " ")}"
      end
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)

  embed_template :migration, """
  defmodule <%= inspect @mod %> do
    use Ecto.Migration

    def change do
  <%= @change %>
    end
  end
  """
end
