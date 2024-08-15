# Delete existing GenX results, run Genx, then run Macro and compare
genx_results = joinpath(@__DIR__,"three_zones_genx","results")
if isdir(genx_results)
    rm(genx_results)
end
include(joinpath(@__DIR__,"three_zones_genx","run.jl"))
include(joinpath(@__DIR__,"three_zones_macro_updated_inputs","run.jl"))
