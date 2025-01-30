###### ###### ###### ###### ###### ######
# Functions for the user to load a system based on JSON files
###### ###### ###### ###### ###### ######

function load_system(
    path::AbstractString = pwd();
    lazy_load::Bool=true,
)::System

    # The path should either be a a file path to a JSON file, preferably "system_data.json"
    # or a directory containing "system_data.json"

    if isdir(path)
        path = joinpath(path, "system_data.json")
    end

    if isjson(path)
        system = empty_system(dirname(path))
        system_data = load_system_data(path; lazy_load = lazy_load)
        generate_system!(system, system_data)
        @show system.settings.Scaling
        if system.settings.Scaling
            scaling!(system)
        end
        return system
    else
        throw(
            ArgumentError(
                "
    No system data found in $path
    Either provide a path to a .JSON file or a directory containing a system_data.json file
",
            ),
        )
    end
end

function load_system(
    system_data::AbstractDict{Symbol,Any},
    dir_path::AbstractString = pwd()
)::System
    # The path should point to the location of the system data files
    # If path is not provided, we assume the data is in the current working directory
    if isfile(dir_path)
        dir_path = dirname(dir_path)
    end
    system = empty_system(dir_path)
    generate_system!(system, system_data)
    return system
end
