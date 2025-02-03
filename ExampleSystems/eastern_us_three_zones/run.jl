using Macro
using Gurobi

(system, model) = Macro.run_case(@__DIR__; optimizer=Gurobi.Optimizer);