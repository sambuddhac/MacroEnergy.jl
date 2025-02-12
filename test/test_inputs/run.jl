using Macro
using Gurobi

(system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);

println()
