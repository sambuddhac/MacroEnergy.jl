using CSV
using JuMP
using DataFrames

struct Resource
    name::String
    type::String
    zone::String
    fixedcost::Float64
    variablecost::Float64
    capacity::Float64
    _capacity::GenericAffExpr{Float64,VariableRef},
    power::Array{Float64,1}
    _power::Array{GenericAffExpr{Float64,VariableRef},1}
end

function makeresource(name::String, type::String, zone::String, fixedcost::Float64, variablecost::Float64)
    return Resource(name, type, zone, fixedcost, variablecost, 0.0, AffExpr())
end

function makeresource(row::DataFrameRow)
    return Resource(row.Name, row.Type, row.Zone, row.Fixed_Cost, row.Variable_Cost, 0.0, AffExpr())
end

function loadresources(filepath)
    resources = Resource[]
    df = CSV.read(filepath, DataFrame)
    for row in eachrow(df)
        push!(resources, makeresource(row))
    end
    return resources
end

###### ###### ###### ###### ###### ######

function power_leq_capacity(model::Model, resource::Resource)
    pow_leq_cap = @constraint(model, resource._capacity <= resource.capacity)
end