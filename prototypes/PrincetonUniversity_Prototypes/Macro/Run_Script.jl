###############cd("prototypes/PrincetonUniversity_Prototypes/Macro")
using Pkg
Pkg.activate(".")

using Revise
using Macro

setup = Dict()
#setup["commodities"] = [Electricity, Hydrogen,NaturalGas];
setup["commodities"] = [Electricity];
setup["PeriodLength"] = 24;
setup["hours_per_subperiod"] = 24;
setup[Electricity] = Dict{Any,Any}("hours_per_timestep"=>1);
setup[Hydrogen] = Dict{Any,Any}("hours_per_timestep"=>1);
#setup[NaturalGas] = Dict("hours_per_timestep"=>24);
setup[Electricity]["resource_filepath"] = "ExampleSystems/Electricity/resources.csv"
setup[Electricity]["node_filepath"] = "ExampleSystems/Electricity/nodes.csv"
setup[Electricity]["edge_filepath"] = "ExampleSystems/Electricity/edges.csv"
# setup[Hydrogen]["resource_filepath"] = missing;
# setup[Hydrogen]["node_filepath"] = "ExampleSystems/Electricity/nodes.csv"
# setup[Hydrogen]["edge_filepath"] = missing;

### setup["transformation_filepath"] = "ExampleSystems/transformations.csv"

resources,edges,nodes = prepare_inputs!(setup);

model = generate_model(resources,edges,nodes,setup);


println()

