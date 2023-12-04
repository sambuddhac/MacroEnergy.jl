Base.@kwdef struct InputFilesNames
    network::String = "Network.csv"
    tedges::String = "TEdges.csv"
    demand::String = "Demand.csv"
    resources::String = "Resources.csv"
    storage::String = "Storage.csv"
    nodes::String = "Nodes.csv"
    transformations::String = "Transformations.csv"
    variability::String = "Variability.csv"
    fuel_prices::String = "Fuel_Price.csv"
    constraints::String = "Constraints.csv"
end

struct InputData
    settings::NamedTuple
    nodes::Dict
    networks::Dict
    resources::Dict
    storage::Dict
    transformations::Vector{Transformation}
end
settings(data::InputData) = data.settings
nodes(data::InputData) = data.nodes
networks(data::InputData) = data.networks
resources(data::InputData) = data.resources
storage(data::InputData) = data.storage
transformations(data::InputData) = data.transformations

@doc raw"""
	load_inputs(setup::Dict,path::AbstractString)

Loads various data inputs from multiple input .csv files in path directory and stores variables in a Dict (dictionary) object for use in model() function

inputs:
setup - dict object containing setup parameters
path - string path to working directory

returns: Dict (dictionary) object containing all data inputs
"""
function load_inputs(settings::NamedTuple, input_path::AbstractString)

    filenames = InputFilesNames()
    @info "Reading in CSV Files from $input_path"

    hours_per_subperiod = settings.HoursPerSubperiod
    period_length = settings.PeriodLength

    # Read in all the commodities
    commodities = commodity_type.(keys(settings.Commodities))

    # Define data structures to store input data
    nodes_all = Dict()
    networks = Dict(zip(commodities, repeat([], length(commodities))))
    resources = Dict(zip(commodities, repeat(Vector{Resource}[], length(commodities))))
    storages = Dict(zip(commodities, [Storage() for c in commodities]))
    transformations = Vector{TEdge}()

    # Read in data for each commodity
    for commodity_name in keys(settings.Commodities)
        commodity = commodity_type(commodity_name)

        inputfolder_path = joinpath(input_path, commodity_name)

        # Commodity specific settings
        commodity_settings = settings.Commodities[commodity_name]

        hours_per_timestep = commodity_settings["HoursPerTimeStep"]
        time_interval = 1:hours_per_timestep:period_length
        subperiods = collect(
            Iterators.partition(
                time_interval,
                Int(hours_per_subperiod / hours_per_timestep),
            ),
        )

        # Read nodes, demand, and fuel prices
        node_file = filenames.nodes
        demand_file = filenames.demand
        fuel_prices_file = filenames.fuel_prices
        nodes = load_nodes(
            joinpath(inputfolder_path, node_file),
            joinpath(inputfolder_path, demand_file),
            joinpath(inputfolder_path, fuel_prices_file),
            commodity,
            time_interval,
        )
        nodes_all[commodity] = nodes

        # Read in network related inputs
        network_file = filenames.network
        if isfile(joinpath(inputfolder_path, network_file))
            networks[commodity] = load_network(
                joinpath(inputfolder_path, network_file),
                nodes,
                commodity,
                time_interval,
            )
        end

        # Read in generator/resource related inputs
        resource_file = filenames.resources
        if isfile(joinpath(inputfolder_path, resource_file))
            res = load_resources(
                joinpath(inputfolder_path, resource_file),
                nodes,
                commodity,
                time_interval,
                subperiods,
            )

            # Read in generator/resource availability profiles
            variability_file = filenames.variability
            load_variability!(joinpath(inputfolder_path, variability_file), res)
            resources[commodity] = res
        end

        # Read in storage related inputs
        storage_file = filenames.storage
        if isfile(joinpath(inputfolder_path, storage_file))
            storages[commodity] = load_storage(
                joinpath(inputfolder_path, storage_file),
                nodes,
                commodity,
                time_interval,
                subperiods,
            )
        end

        # # Read constraints
        # constraints_file = filenames.constraints
        # load_constraints!(joinpath(inputfolder_path, constraints_file))
    end

    # collect all nodes actoss commodities
    nodes = merge([nodes_all[i] for i in commodities]...)

    # Read in transformation related inputs
    tedges_file = filenames.tedges
    transformations_file = filenames.transformations
    transformations = load_tedges(
        joinpath(input_path, tedges_file),
        joinpath(input_path, transformations_file),
        nodes,
    )

    @info "CSV Files Successfully Read In From $input_path"
    return InputData(settings, nodes, networks, resources, storages, transformations)
end
