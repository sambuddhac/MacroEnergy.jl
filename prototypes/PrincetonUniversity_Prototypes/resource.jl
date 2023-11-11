Base.@kwdef mutable struct Resource{T} <: AbstractResource{T}
    node::Int64;
    r_id::Int64;
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0;
    fixed_om_cost::Float64 = 0.0;
    variable_om_cost::Float64 = 0.0;
    capacity_factor ::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]],1.0)
    # capacity_factor :: Vector{Float64} = ones(time_interval_map[T])
    _capacity::Array{VariableRef}  = VariableRef[]
    _new_capacity::Array{VariableRef}  = VariableRef[]
    _ret_capacity::Array{VariableRef} = VariableRef[]
    #_injection::Array{VariableRef} = Array{VariableRef}(undef,time_interval_map[T])
    _injection::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    constraints::Vector{AbstractConstraint} = [CapacityConstraint{T}()] 
end

existing_capacity(g::AbstractResource) = g.existing_capacity;
new_capacity(g::AbstractResource) = g._new_capacity[1];
ret_capacity(g::AbstractResource) = g._ret_capacity[1];
capacity(g::AbstractResource) = g._capacity[1];
injection(g::AbstractResource) = g._injection;

function add_planning_variables!(g::AbstractResource,model::Model)
    
    g._new_capacity = [@variable(model,lower_bound=0.0,base_name="vNEWCAP_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity = [@variable(model,lower_bound=0.0,base_name="vRETCAP_$(commodity_type(g))_$(g.r_id)")]

    g._capacity = [@variable(model,lower_bound=0.0,base_name="vCAP_$(commodity_type(g))_$(g.r_id)")]

    ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
    @constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    if !g.can_expand
        fix(new_capacity(g),0.0; force=true)
    end
    
    if !g.can_retire
        fix(ret_capacity(g),0.0; force=true)
    end

    return nothing

end

function add_operation_variables!(g::AbstractResource,model::Model)

    g._injection = @variable(model,[t in time_interval(g)],lower_bound=0.0,base_name="vINJ_$(commodity_type(g))_$(g.r_id)")

end

function add_fixed_cost!(g::AbstractResource,model::Model)

    model[:eFixedCost] += g.investment_cost*new_capacity(g) + g.fixed_om_cost*capacity(g)

end

function add_variable_cost!(g::Resource,model::Model)

    model[:eVariableCost] += g.variable_om_cost*sum(injection(g))

end
