"""
    BaseResource    

This type defines the common fields of all resources.
    """
Base.@kwdef mutable struct BaseResource{T<:Commodity}
    node::Int64
    r_id::Int64
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    variable_om_cost::Float64 = 0.0
    capacity_factor::DenseAxisArray = Containers.@container([t in time_interval_map[T]], 1.0)
    # capacity_factor :: Vector{Float64} = ones(time_interval_map[T])
    _capacity::Vector{VariableRef} = VariableRef[]
    _new_capacity::Vector{VariableRef} = VariableRef[]
    _ret_capacity::Vector{VariableRef} = VariableRef[]
    #_injection::Vector{VariableRef} = Array{VariableRef}(undef,time_interval_map[T])
    _injection::DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    constraints::Vector{AbstractConstraint} = [CapacityConstraint{T}()]
end

"""
    AbstractResource

An abstract type for a generic resource. This type is used to define the common interface of all resources. The type parameter T is used to define the commodity type of the resource.
It must contain the following field:
- base::BaseResource{T}: a field of type BaseResource{T} that contains the common fields of all resources.
"""
abstract type AbstractResource{T<:Commodity} end

function Base.getproperty(r::AbstractResource, p::Symbol)
    if p ∈ fieldnames(BaseResource)
        base = getfield(r, :base)
        return getfield(base, p)
    else
        return getfield(r,p)
    end
end

function Base.setproperty!(r::AbstractResource, p::Symbol, v)
    if p ∈ fieldnames(BaseResource)
        base = getfield(r, :base)
        return setfield!(base, p, v)
    else
        return setfield!(r, p, v)
    end
end

# Resource interface
commodity_type(g::AbstractResource{T}) where {T} = T;
time_interval(g::AbstractResource) = time_interval_map[commodity_type(g)];
existing_capacity(g::AbstractResource) = g.existing_capacity;
new_capacity(g::AbstractResource) = g._new_capacity[1];
ret_capacity(g::AbstractResource) = g._ret_capacity[1];
capacity(g::AbstractResource) = g._capacity[1];
injection(g::AbstractResource) = g._injection;
resource_id(g::AbstractResource) = g.r_id;
node(g::AbstractResource) = g.node;
min_capacity(g::AbstractResource) = g.min_capacity;
max_capacity(g::AbstractResource) = g.max_capacity;
can_expand(g::AbstractResource) = g.can_expand;
can_retire(g::AbstractResource) = g.can_retire;
constraints(g::AbstractResource) = g.constraints;


mutable struct VRE{T} <: AbstractResource{T}
    base::BaseResource{T}
    # other fields specific to VREs
    # field 1
    # field 2
    # ctor for VRE
    function VRE{T}(; kwargs...) where {T}
        base_fields = fieldnames(BaseResource)
        base_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k in base_fields)
        VRE_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k ∉ base_fields)
        return new(BaseResource{T}(; base_kwargs...), VRE_kwargs...)
    end
end

mutable struct Solar{T} <: AbstractResource{T}
    base::BaseResource{T}
    # other fields specific to Solar
    # field 1
    # field 2
    # ctor for Solar
    function Solar{T}(;kwargs...) where {T}
        base_fields = fieldnames(BaseResource)
        base_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k in base_fields)
        Solar_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k ∉ base_fields)
        return new(BaseResource{T}(; base_kwargs...), Solar_kwargs...)
    end
end

# add_variable  functions
function add_planning_variables!(g::AbstractResource, model::JuMP.Model)

    g._new_capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vNEWCAP_$(commodity_type(g))_$(resource_id(g))")]

    g._ret_capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vRETCAP_$(commodity_type(g))_$(resource_id(g))")]

    g._capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vCAP_$(commodity_type(g))_$(resource_id(g))")]

    ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
    JuMP.@constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    if !can_expand(g)
        fix(new_capacity(g), 0.0; force=true)
    end

    if !can_retire(g)
        fix(ret_capacity(g), 0.0; force=true)
    end

    return nothing

end

function add_operation_variables!(g::AbstractResource, model::JuMP.Model)

    g._injection = JuMP.@variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vINJ_$(commodity_type(g))_$(resource_id(g))")

end

function add_fixed_cost!(g::AbstractResource, model::JuMP.Model)

    model[:eFixedCost] += g.investment_cost * new_capacity(g) + g.fixed_om_cost * capacity(g)

end

function add_variable_cost!(g::AbstractResource, model::JuMP.Model)

    model[:eVariableCost] += g.variable_om_cost * sum(injection(g))

end

function add_all_model_constraints!(g::AbstractResource,model::JuMP.Model)

    for ct in g.constraints
        add_model_constraint!(ct,g,model)
    end

    return nothing
end

function add_model_constraint!(mycon::CapacityConstraint,g::AbstractResource,model::JuMP.Model)

    mycon._constraintref = JuMP.@constraint(model,[t in time_interval(g)],injection(g)[t] <= g.capacity_factor[t]*capacity(g))

    return nothing

end
