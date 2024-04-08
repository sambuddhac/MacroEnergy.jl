using Macro

# test_case_path = joinpath("ExampleSystems", "Macro_3Zone_SmallNewEngland")
test_case_path = joinpath(dirname(dirname(@__DIR__)), "test", "test_inputs")

macro_settings = Macro.configure_settings(joinpath(test_case_path, "settings", "macro_settings.yml"))

# Load and create all the Nodes
system_path = joinpath(test_case_path, "system")

# Read in all the commodities
commodities = Macro.load_commodities_json(system_path)

# Read in time data
time_data = Macro.load_time_json(system_path, commodities)

# Read in all the nodes
network_data = joinpath(system_path, "network")
nodes = Macro.load_nodes_json(network_data, time_data)

# Create the network (aka Edges) between Nodes

# Load all the transformation data
transformations, T = load_transformations_json(joinpath(test_case_path,"transforms"), macro_settings)

# Create all the transformations

# Store everything in the InputData struct
# InputData(macro_settings, node_d, network_d, resource_d, storage_d, transformations), macro_settings

# Generate model based on the InputData
# model = Macro.generate_model(macro_inputs);

# Solve the model
# set_optimizer(model,Gurobi.Optimizer)
# optimize!(model)

# # Write the outputs