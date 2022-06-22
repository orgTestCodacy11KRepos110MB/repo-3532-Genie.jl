module Watch

using Revise
using Genie
using Logging
using Dates

const _task = Ref{Core.Task}()
const WATCHED_FOLDERS = Ref{Vector{String}}(String[])

function collect_watched_files(files::Vector{String} = WATCHED_FOLDERS[], extensions::Vector{String} = Genie.config.watch_extensions) :: Vector{String}
  result = String[]

  for f in files
    push!(result, Genie.Util.walk_dir(f, only_extensions = extensions)...)
  end

  result |> unique
end

function handlers()
  Genie.config.watch_handlers |> values |> collect
end

function watch(files::Vector{String}, extensions::Vector{String} = Genie.config.watch_extensions) :: Nothing
  push!(WATCHED_FOLDERS[], files...)
  WATCHED_FOLDERS[] = unique(WATCHED_FOLDERS[])
  last_watched = now()

  Revise.revise()

  _task[] = @async entr(collect_watched_files(WATCHED_FOLDERS[], extensions); all = true, postpone = true) do
    now() - last_watched > Millisecond(1_000) || return
    last_watched = now()

    for fg in handlers()
      for f in fg
        @async Base.invokelatest(f)
      end
    end

    last_watched = now()
  end

  nothing
end

watch(files::String, extensions::Vector{String} = Genie.config.watch_extensions) = watch(String[files], extensions)
watch(files...; extensions::Vector{String} = Genie.config.watch_extensions) = watch(String[files...], extensions)
watch() = watch(String[])

function unwatch(files::Vector{String}) :: Nothing
  filter!(e -> !(e in files), WATCHED_FOLDERS[])
  watch()
end
unwatch(files...) = unwatch(String[files...])

end