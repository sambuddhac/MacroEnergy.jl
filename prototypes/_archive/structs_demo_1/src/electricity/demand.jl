using CSV
using DataFrames

struct elec_demand
    zone::String
    sector::String = "electricity"
    demand::Vector{Float64}
end

function loadElecDemand(filepath)
    elec_demands = Vector(elec_demand)
    df = CSV.read(filepath, DataFrame)
    for (name, col) in pairs(eachcol(df))
        elec_demands = push!(elec_demands, elec_demand(zone = name, demand = col))
    end
    return elec_demands
end
