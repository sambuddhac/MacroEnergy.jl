using CSV
using DataFrames

struct Demand
    zone::String
    demand::Vector{Float64}
    sector::String
    profiletype::String
end

function makeelecdemand(zone::String, demand::Vector{Float64}, sector::String="electricity", profiletype::String="components")
    return Demand(zone, demand, sector,  profiletype)
end

function loadelecdemands(filepath)
    elec_demands = Demand[]
    df = CSV.read(filepath, DataFrame)
    for (name, col) in pairs(eachcol(df))
        push!(elec_demands, makeelecdemand(string(name), col))
    end
    return elec_demands
end