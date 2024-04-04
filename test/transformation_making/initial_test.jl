using Macro

# test_case_path = joinpath("ExampleSystems", "Macro_3Zone_SmallNewEngland")
test_case_path = joinpath(dirname(dirname(@__DIR__)), "ExampleSystems", "Macro_3Zone_SmallNewEngland")

macro_settings = Macro.configure_settings(joinpath(test_case_path, "Settings", "macro_settings.yml"))

# Load and create all the Nodes
# nodes = load_nodes_json(data_dir, macro_settings)

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