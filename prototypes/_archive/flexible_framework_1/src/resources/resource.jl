using CSV
using JuMP
using DataFrames

struct Resource
    name::String
    type::String
    zone::String
    fixedcost::Float64
    variablecost::Float64
end
 
###### ###### ###### ###### ###### ######

function makeresource(name::String, type::String, zone::String, fixedcost::Float64, variablecost::Float64)
    return Resource(name, type, zone, fixedcost, variablecost)
end

function makeresource(row::DataFrameRow)
    return Resource(row.Name, row.Type, row.Zone, row.Fixed_Cost, row.Variable_Cost)
end

###### ###### ###### ###### ###### ######

function power_leq_capacity(model::Model, resource::Resource)
    pow_leq_cap = @constraint(model, resource._capacity <= resource.capacity)
end

function power_geq_zero(model::Model, resource::Resource)
    pow_geq_zero = @constraint(model, resource._capacity >= 0)
end

function power_ramp_limit(model::Model, resource::Resource)
    pow_ramp_limit = @constraint(model, resource._capacity - resource._prev_capacity <= resource.ramp_limit)
end