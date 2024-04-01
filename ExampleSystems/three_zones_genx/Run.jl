using Pkg

Pkg.activate("/Users/fp0820/Code/Genx.jl/")

using GenX, Gurobi

run_genx_case!(dirname(@__FILE__),Gurobi.Optimizer)