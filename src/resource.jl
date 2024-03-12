"""
    AbstractResource

An abstract type for a generic resource. This type is used to define the common interface of all resources. The type parameter T is used to define the commodity type of the resource.
It must contain the following field:
- base::BaseResource{T}: a field of type BaseResource{T} that contains the common fields of all resources.
"""
abstract type AbstractResource{T<:Commodity} end

# Resource interface
commodity_type(g::AbstractResource{T}) where {T} = T;
capacity_size(g::AbstractResource) = g.capacity_size;
time_interval(g::AbstractResource) = g.time_interval;
subperiods(g::AbstractResource) = g.subperiods;
existing_capacity(g::AbstractResource) = g.existing_capacity;
capacity_factor(g::AbstractResource) = g.capacity_factor;
price(g::AbstractResource) = g.price;
get_id(g::AbstractResource) = g.id;
node(g::AbstractResource) = g.node;
investment_cost(g::AbstractResource) = g.investment_cost;
fixed_om_cost(g::AbstractResource) = g.fixed_om_cost;
variable_om_cost(g::AbstractResource) = g.variable_om_cost;
min_capacity(g::AbstractResource) = g.min_capacity;
max_capacity(g::AbstractResource) = g.max_capacity;
can_expand(g::AbstractResource) = g.can_expand;
can_retire(g::AbstractResource) = g.can_retire;
new_capacity(g::AbstractResource) = g.planning_vars[:new_capacity];
ret_capacity(g::AbstractResource) = g.planning_vars[:ret_capacity];
capacity(g::AbstractResource) = g.planning_vars[:capacity];
injection(g::AbstractResource) = g.operation_vars[:injection];
all_constraints(g::AbstractResource) = g.constraints;

Base.@kwdef mutable struct Resource{T} <: AbstractResource{T}
    ### Mandatory fields: (fields without defaults)
    node::AbstractNode{T}
    id::Symbol
    #### Optional fields - (fields with defaults)
    capacity_factor::Vector{Float64} = Float64[]
    capacity_size::Float64 = 1.0
    price::Vector{Float64} = Float64[]
    time_interval::StepRange{Int64,Int64} = 1:1
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    variable_om_cost::Float64 = 0.0
    planning_vars::Dict = Dict{Symbol,Any}()
    operation_vars::Dict = Dict{Symbol,Any}()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end

Base.@kwdef mutable struct Sink{T} <: AbstractResource{T}
    ### Mandatory fields: (fields without defaults)
    node::AbstractNode{T}
    id::Symbol
    #### Optional fields - (fields with defaults)
    price::Vector{Float64} = Float64[]
    time_interval::StepRange{Int64,Int64} = 1:1
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    operation_vars::Dict = Dict{Symbol,Any}()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end
withdrawal(g::Sink) = g.operation_vars[:withdrawal];

# add_variable  functions
function add_planning_variables!(g::AbstractResource, model::Model)

    if existing_capacity(g) == Inf
        return nothing
    else
        g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(get_id(g))"
        )

        g.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(get_id(g))"
        )

        g.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAP_$(get_id(g))"
        )

        ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
        @constraint(
            model,
            capacity(g) == capacity_size(g)*(new_capacity(g) - ret_capacity(g)) + existing_capacity(g)
        )

        if !can_expand(g)
            fix(new_capacity(g), 0.0; force = true)
        else
            add_to_expression!(model[:eFixedCost], investment_cost(g)*capacity_size(g), new_capacity(g))
        end

        if !can_retire(g)
            fix(ret_capacity(g), 0.0; force = true)
        end

        if fixed_om_cost(g)>0
            add_to_expression!(model[:eFixedCost], fixed_om_cost(g), capacity(g))
        end

        return nothing
    end

end

function add_operation_variables!(g::AbstractResource, model::Model)
    n = node(g)

    g.operation_vars[:injection] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vINJ_$(get_id(g))"
    )

    add_to_expression!.(net_production(n), injection(g))

    for t in time_interval(g)

        # add_to_expression!(net_production(n)[t], injection(g)[t])

        if !isempty(price(g))
            add_to_expression!(model[:eVariableCost], price(g)[t], injection(g)[t])
        end

        if variable_om_cost(g)>0
            add_to_expression!(model[:eVariableCost], variable_om_cost(g), injection(g)[t])
        end

    end

    return nothing
end

function add_planning_variables!(g::Sink, model::Model)
    
    return nothing

end

function add_operation_variables!(g::Sink, model::Model)
    n = node(g)

    g.operation_vars[:withdrawal] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vWDW_$(get_id(g))"
    )

    add_to_expression!.(net_production(n), -withdrawal(g))

    for t in time_interval(g)
        if !isempty(price(g))
            add_to_expression!(model[:eVariableCost], price(g)[t], withdrawal(g)[t])
        end
    end

    return nothing
end

function add_model_constraint!(ct::CapacityConstraint, g::AbstractResource, model::Model)

    cap_factor = Dict(collect(time_interval(g)) .=> capacity_factor(g))

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        injection(g)[t] <= cap_factor[t] * capacity(g)
    )

    return nothing

end