# Delete existing GenX results, run Genx, then run Macro and compare
rm(joinpath(@__DIR__,"three_zones_genx","results"))
include(joinpath(@__DIR__,"three_zones_genx","run.jl"))
include(joinpath(@__DIR__,"three_zones_macro","run.jl"))
