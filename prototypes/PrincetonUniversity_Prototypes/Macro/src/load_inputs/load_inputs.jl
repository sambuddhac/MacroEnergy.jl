Base.@kwdef struct InputFilesNames
    network::String = "Network.csv"
    demand::String = "Demand.csv"
    resources::String = "Resources.csv"
    transformations::String = "Transformations.csv"
    variability::String = "Variability.csv"
    fuel_prices::String = "Fuel_Prices.csv"
    constraints::String = "Constraints.csv"
end

mutable struct InputData
    settings::NamedTuple
    network::Network
    resources::Vector{Resource}
    transformations::Vector{Transformation}
    storages::Vector{Storage}
end
settings(data::InputData) = data.settings
network(data::InputData) = data.network
resources(data::InputData) = data.resources
transformations(data::InputData) = data.transformations
storages(data::InputData) = data.storages

# struct TimeSeries
# 	time_index::Vector{Int64}
# 	demand::NamedTuple	# one vector per zone
# 	fuel_prices::NamedTuple # one matrix per fuel and zone
# end

@doc raw"""
	load_inputs(setup::Dict,path::AbstractString)

Loads various data inputs from multiple input .csv files in path directory and stores variables in a Dict (dictionary) object for use in model() function

inputs:
setup - dict object containing setup parameters
path - string path to working directory

returns: Dict (dictionary) object containing all data inputs
"""
function load_inputs(settings::NamedTuple, inputfolder_path::AbstractString)

    filenames = InputFilesNames()
    @info "Reading in CSV Files From $path"

    # Read input data about power network topology, operating and expansion attributes
    network_file = filenames.network
    network = load_network(joinpath(inputfolder_path, network_file))

    # Read temporal-resolved load data, and clustering information if relevant
    demand_file = filenames.demand
    load_demand!(joinpath(inputfolder_path, demand_file), network)

    # Read in generator/resource related inputs
    resource_file = filenames.resources
    resources = load_resources(joinpath(inputfolder_path, resource_file))

    # Read in transformation related inputs
    transformation_file = filenames.transformations
    transformations = load_transformations(joinpath(inputfolder_path, transformation_file))

    # Read in storage related inputs
    storage_file = filenames.storages
    storages = load_storages(joinpath(inputfolder_path, storage_file))

    # Read in generator/resource availability profiles
    variability_file = filenames.variability
    load_variability!(joinpath(inputfolder_path, variability_file), resources)

    # Read fuel cost data, including time-varying fuel costs
    fuel_prices = filenames.fuel_prices
    load_fuel_prices!(joinpath(inputfolder_path, fuel_prices), resources)

    # Read constraints
    constraints_file = filenames.constraints
    load_constraints!(joinpath(inputfolder_path, constraints_file))

    println("CSV Files Successfully Read In From $path")
    return InputData(settings, network, resources, transformations, storages)
end
