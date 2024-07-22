using Pkg

case = dirname(@__FILE__)

Pkg.activate(dirname(dirname(case)))

using Distributed

addprocs(5)

@everywhere begin
    import Pkg
    Pkg.activate(dirname(dirname(dirname(@__FILE__))))
    using Macro
end

test_case_path = joinpath(dirname(dirname(@__DIR__)), "ExampleSystems", "three_zones_macro_benders")

macro_settings = Macro.configure_settings(joinpath(test_case_path, "settings", "macro_settings.yml"))

# Load and create all the Nodes
system_path = joinpath(test_case_path, "system")

# Read in all the commodities
commodities = Macro.load_commodities_json(system_path)

# Read in time data
time_data = Macro.load_time_json(system_path, commodities)

# Read in all the nodes
network_dir = joinpath(system_path, "network")
nodes = Macro.load_nodes_json(network_dir, time_data)

# Read in demand data
Macro.load_demand_data!(nodes, system_path)

# Create the network (aka Edges) between Nodes
edges = Macro.load_edges_json(network_dir, time_data, nodes)

# Load all the asset data
asset_dir = joinpath(test_case_path, "assets")
assets = Macro.load_assets_json(asset_dir, time_data, nodes)

# Load the capacity factor data for the assets
Macro.load_capacity_factor!(assets, asset_dir)

# Read in fuel data and CO2 emissions
Macro.load_fuel_data!(system_path, assets)

system = Macro.create_system(nodes, edges, assets)

benders_data = Macro.generate_benders_data(system,time_data);

_,planning_sol,LB_hist,UB_hist,cpu_time  = Macro.benders(benders_data);

monolithic_objval = 1.0305035794420805e10

println()