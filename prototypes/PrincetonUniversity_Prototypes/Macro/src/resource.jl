"""
    AbstractResource

An abstract type for a generic resource. This type is used to define the common interface of all resources. The type parameter T is used to define the commodity type of the resource.
It must contain the following field:
- base::BaseResource{T}: a field of type BaseResource{T} that contains the common fields of all resources.
"""
abstract type AbstractResource{T<:Commodity} end

# Resource interface
commodity_type(g::AbstractResource{T}) where {T} = T;
time_interval(g::AbstractResource) = g.time_interval;
subperiods(g::AbstractResource) = g.subperiods;
existing_capacity(g::AbstractResource) = g.existing_capacity;
capacity_factor(g::AbstractResource) = g.capacity_factor;
price(g::AbstractResource) = g.price;
resource_id(g::AbstractResource) = g.id;
node(g::AbstractResource) = g.node;
investment_cost(g::AbstractResource) = g.investment_cost;
fixed_om_cost(g::AbstractResource) = g.fixed_om_cost;
min_capacity(g::AbstractResource) = g.min_capacity;
max_capacity(g::AbstractResource) = g.max_capacity;
can_expand(g::AbstractResource) = g.can_expand;
can_retire(g::AbstractResource) = g.can_retire;
new_capacity(g::AbstractResource) = g.planning_vars[:new_capacity];
ret_capacity(g::AbstractResource) = g.planning_vars[:ret_capacity];
capacity(g::AbstractResource) = g.planning_vars[:capacity];
injection(g::AbstractResource) = g.operation_vars[:injection];
all_constraints(g::AbstractResource) = g.constraints;

map_resource_to_node(g::AbstractResource, nodes::Vector{AbstractNode}) = nodes[node(g)];




Base.@kwdef mutable struct Resource{T} <: AbstractResource{T}
    ### Mandatory fields: (fields without defaults)
    node::Node{T}
    id::Symbol
    #### Optional fields - (fields with defaults)
    capacity_factor::Vector{Float64} = Float64[]
    # price::Vector{Float64} = Float64[]    #TODO: talk with Filippo about this
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
    constraints::Vector{AbstractTypeConstraint} = [CapacityConstraint{T}()]
end

Base.@kwdef mutable struct Thermal{T} <: AbstractResource{T}
    ### Fields without defaults
    node::Int64
    r_id::Int64
    capacity_factor::Vector{Float64}  # = ones(length(time_interval_map[T]))
    # price::Vector{Float64} # = zeros(length(time_interval_map[T]))    #TODO: talk with Filippo about this
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}}
    #### Fields with defaults
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    variable_om_cost::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
end


# add_variable  functions
function add_planning_variables!(g::AbstractResource, model::Model)

    g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(commodity_type(g))_$(resource_id(g))"
    )

    g.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(commodity_type(g))_$(resource_id(g))"
    )

    g.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAP_$(commodity_type(g))_$(resource_id(g))"
    )

    ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
    @constraint(
        model,
        capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g)
    )

    if !can_expand(g)
        fix(new_capacity(g), 0.0; force = true)
    end

    if !can_retire(g)
        fix(ret_capacity(g), 0.0; force = true)
    end

    return nothing

end


function add_operation_variables!(
    g::AbstractResource,
    all_nodes::Vector{AbstractNode},
    model::Model,
)

    n = map_resource_to_node(g, all_nodes)

    g.operation_vars[:injection] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vINJ_$(commodity_type(g))_$(resource_id(g))"
    )

    for t in time_interval(g)
        add_to_expression!(net_energy_production(n)[t], injection(g)[t])
    end

    return nothing
end
