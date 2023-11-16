###############cd("prototypes/PrincetonUniversity_Prototypes/Macro")
using Pkg
Pkg.activate(".")

using Revise
using Macro

setup = Dict()
#setup["commodities"] = [Electricity, Hydrogen];
setup["commodities"] = [Electricity];
setup["PeriodLength"] = 12;
setup["hours_per_subperiod"] = 4;
setup[Electricity] = Dict{Any,Any}("hours_per_timestep"=>1);
#setup[Hydrogen] = Dict("hours_per_timestep"=>2);
setup[Electricity]["filepath"] = "ExampleSystems/Electricity/resources.csv"

resources = prepare_inputs!(setup);

model = generate_model(resources,setup);


println()

