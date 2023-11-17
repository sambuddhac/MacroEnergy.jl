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
#setup[Hydrogen] = Dict("hours_per_timestep"=>1);
#setup[NaturalGas] = Dict("hours_per_timestep"=>24);
setup[Electricity]["filepath"] = "ExampleSystems/Electricity/resources.csv"

resources = prepare_inputs!(setup);

model = generate_model(resources,setup);


println()

