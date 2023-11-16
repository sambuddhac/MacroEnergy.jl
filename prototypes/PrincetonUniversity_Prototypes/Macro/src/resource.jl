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
resource_id(g::AbstractResource) = g.r_id;
node(g::AbstractResource) = g.node;
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
    ### Fields without defaults
    node::Int64
    r_id::Int64
    capacity_factor :: Vector{Float64}  # = ones(length(time_interval_map[T]))
    price::Vector{Float64} # = zeros(length(time_interval_map[T]))
    time_interval::StepRange{Int64, Int64}
    subperiods::Vector{StepRange{Int64, Int64}}
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
    constraints ::Vector{AbstractTypeConstraint}=[CapacityConstraint{T}()]
end

Base.@kwdef mutable struct Thermal{T} <: AbstractResource{T}
    ### Fields without defaults
    node::Int64
    r_id::Int64
    capacity_factor :: Vector{Float64}  # = ones(length(time_interval_map[T]))
    price::Vector{Float64} # = zeros(length(time_interval_map[T]))
    time_interval::StepRange{Int64, Int64}
    subperiods::Vector{StepRange{Int64, Int64}}
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
