using CSV
using DataFrames

struct Resource
    name::String
    type::String
    zone::String
    fixedcost::Float64
    variablecost::Float64
end

function makeresource(
    name::String,
    type::String,
    zone::String,
    fixedcost::Float64,
    variablecost::Float64,
)
    return Resource(name, type, zone, fixedcost, variablecost)
end

function makeresource(row::DataFrameRow)
    return Resource(row.Name, row.Type, row.Zone, row.Fixed_Cost, row.Variable_Cost)
end

function loadresources(filepath)
    resources = Resource[]
    df = CSV.read(filepath, DataFrame)
    for row in eachrow(df)
        push!(resources, makeresource(row))
    end
    return resources
end
