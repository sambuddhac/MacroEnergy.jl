abstract type AbstractEdge{T<:Commodity} end

Base.@kwdef mutable struct Edge{T} <: AbstractEdge{T}
    start_node::Int64
    end_node::Int64
    unidirectional::Bool = false
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64
    can_expand::Bool = true
    investment_cost::Float64 = 0.0
    _capacity::Array{VariableRef} = VariableRef[]
    _new_capacity::Array{VariableRef} = VariableRef[]
    _flow::Array{VariableRef} = Array{VariableRef}(undef, time_interval_map[T])
end

time_interval(e::AbstractEdge) = time_interval_map[commodity_type(e)];
commodity_type(e::AbstractEdge{T}) where {T} = T;
exsiting_capacity(e::AbstractEdge) = e.existing_capacity;
new_capacity(e::AbstractEdge) = e._new_capacity[1];
capacity(e::AbstractEdge) = e._capacity[1];
flow(e::AbstractEdge) = e._flow;

function add_planning_variables!(e::AbstractEdge, model::JuMP.Model)

    e._new_capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vNEWCAPEDGE_$(commodity_type(e))_$(e.r_ID)")]

    e._capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vCAPEDGE_$(commodity_type(e))_$(e.r_id)")]

    JuMP.@constraint(model, capacity(e) == new_capacity(e) + existing_capacity(e))

    if !can_expand
        fix(new_capacity, 0.0; force=true)
    end

    return nothing

end

function add_operation_variables!(e::AbstractEdge, model::JuMP.Model)

    g._flow = JuMP.@variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vFLOW_$(commodity_type(g))_$(g.r_id)")

end

function add_fixed_cost!(e::AbstractEdge, model::JuMP.Model)

    model[:eFixedCost] += e.investment_cost * new_capacity(e)

end
