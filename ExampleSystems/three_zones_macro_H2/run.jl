using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

system = Macro.load_system(case_path)

model = Macro.generate_model(system)

Macro.set_optimizer(model,Gurobi.Optimizer);
Macro.optimize!(model)
macro_objval = Macro.objective_value(model)

println("The runtime for Macro was $(Macro.solve_time(model))")

capacity_results = Macro.get_optimal_asset_capacity(system)
write_csv(joinpath(case_path, "capacity.csv"), capacity_results)
println()