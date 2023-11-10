Base.@kwdef mutable struct Resource{T} <: AbstractResource{T}
    Node::Int64;
    R_ID::Int64;
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    policy_membership::Vector{String} = [""]
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0;
    fixed_om_cost::Float64 = 0.0;
    variable_om_cost::Float64 = 0.0;
    capacity_factor :: Vector{Float64} = ones(time_resolution_map[T])
    _capacity::Array{VariableRef}  = VariableRef[]
    _new_capacity::Array{VariableRef}  = VariableRef[]
    _ret_capacity::Array{VariableRef} = VariableRef[]
    _injection::Array{VariableRef} = Array{VariableRef}(undef,time_resolution_map[T])
end

existing_capacity(g::AbstractResource) = g.existing_capacity;
new_capacity(g::AbstractResource) = g._new_capacity[1];
ret_capacity(g::AbstractResource) = g._ret_capacity[1];
capacity(g::AbstractResource) = g._capacity[1];
injection(g::AbstractResource) = g._injection;
existing_capacity_storage(g::AbstractResource) = g.existing_capacity_storage;

function add_capacity_variables!(g::AbstractResource,model::Model)

    g._new_capacity = [@variable(model,lower_bound=0.0,base_name="vNEWCAP_$(resource_type(g))_$(g.R_ID)")]

    g._ret_capacity = [@variable(model,lower_bound=0.0,base_name="vRETCAP_$(resource_type(g))_$(g.R_ID)")]

    g._capacity = [@variable(model,lower_bound=0.0,base_name="vCAP_$(resource_type(g))_$(g.R_ID)")]

    return nothing

end

function add_fixed_costs!(g::AbstractResource,model::Model)

    model[:eFixedCost] += g.investment_cost*new_capacity(g) + g.fixed_om_cost*capacity(g)

end

