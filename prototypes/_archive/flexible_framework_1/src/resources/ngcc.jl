

struct Ngcc <: Resource
    name::String
    type::String
    zone::String
    fixedcost::Float64
    variablecost::Float64
end

function power_ramp_limit(model::Model, resource::Ngcc)
    pow_ramp_limit = @constraint(model, resource._capacity - resource._prev_capacity <= resource.ramp_limit)
end