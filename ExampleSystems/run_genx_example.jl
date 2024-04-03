using Pkg
Pkg.activate(dirname(@__DIR__))

using Revise
using Macro
using Gurobi
using CSV
using DataFrames
using YAML

case_path = pwd()*"/ExampleSystems/three_zones_genx/";
genx_settings = namedtuple(YAML.load_file(case_path*"settings/genx_settings.yml"));

compare_with_TDR = true;


if compare_with_TDR==false
    df_genx_status = CSV.read(case_path*"results_fulltimeseries/Status.csv",DataFrame);
else
    df_genx_status = CSV.read(case_path*"results_withTDR/Status.csv",DataFrame);
end

system, all_timedata = Macro.load_data_from_genx(compare_with_TDR,case_path,genx_settings)

@time model = Macro.generate_model(system);

Macro.set_optimizer(model,Gurobi.Optimizer);
Macro.optimize!(model)
macro_objval = Macro.objective_value(model)

println("The relative error between Macro and GenX is $(abs(df_genx_status.Objval[1]-macro_objval)/df_genx_status.Objval[1])")

println("The runtime for Macro was $(Macro.solve_time(model))")

println("The runtime for GenX was $(df_genx_status.Solve[1])")

println()