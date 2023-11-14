"""
    BaseStorage
This type defines the common fields of all storage resources.
"""
Base.@kwdef mutable struct BaseStorage{T<:Commodity}
    existing_capacity_storage::Float64 = 0.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0
    efficiency_charge::Float64 = 1.0
    efficiency_discharge::Float64 = 1.0
    _capacity_storage::Array{VariableRef} = VariableRef[]
    _new_capacity_storage::Array{VariableRef} = VariableRef[]
    _ret_capacity_storage::Array{VariableRef} = VariableRef[]
    _withdrawal::DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    _storage_level::DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    min_storage_level::Float64 = 0.0
    self_discharge::Float64 = 0.0
end

"""
    AbstractStorage

The `AbstractStorage` type is used to represent a storage resource. 
It is a subtype of `AbstractResource` and must contain the following fields:
- `base::BaseResource{T}`: a field of type `BaseResource{T}` that contains the common fields of all resources.
- `base_storage::BaseStorage{T}`: a field of type `BaseStorage{T}` that contains the common fields of all storage resources.
"""
abstract type AbstractStorage{T} <: AbstractResource{T} end

function Base.getproperty(r::AbstractStorage, p::Symbol)
    if p ∈ fieldnames(BaseResource)
        base = getfield(r, :base)
        return getfield(base, p)
    elseif p ∈ fieldnames(BaseStorage)
        base_storage = getfield(r, :base_storage)
        return getfield(base_storage, p)
    else
        return getfield(r,p)
    end
end

function Base.setproperty!(s::AbstractStorage, p::Symbol, v)
    if p ∈ fieldnames(BaseResource)
        base = getfield(s, :base)
        return setfield!(base, p, v)
    elseif p ∈ fieldnames(BaseStorage)
        base_storage = getfield(s, :base_storage)
        return setfield!(base_storage, p, v)
    else
        return setfield!(s, p, v)
    end
end

# Storage interface
existing_capacity_storage(g::AbstractStorage) = g.existing_capacity_storage;
new_capacity_storage(g::AbstractStorage) = g._new_capacity_storage[1];
ret_capacity_storage(g::AbstractStorage) = g._ret_capacity_storage[1];
capacity_storage(g::AbstractStorage) = g._capacity_storage[1];
withdrawal(g::AbstractStorage) = g._withdrawal;
storage_level(g::AbstractStorage) = g._storage_level;

mutable struct SymmetricStorage{T} <: AbstractStorage{T}
    base::BaseResource{T}
    base_storage::BaseStorage{T}
    # other fields specific to SymmetricStorage
    # field 1
    # field 2
    function SymmetricStorage{T}(;kwargs...) where {T}
        base_fields = fieldnames(BaseResource)
        base_storage_fields = fieldnames(BaseStorage)
        base_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k in base_fields)
        base_storage_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k in base_storage_fields)
        # SymmetricStorage_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k ∉ base_fields && k ∉ base_storage_fields)
        return new{T}(BaseResource{T}(; base_kwargs...), 
                BaseStorage{T}(; base_storage_kwargs...))
    end
end

Base.@kwdef mutable struct AsymmetricStorage{T} <: AbstractStorage{T}
    base::BaseResource{T}
    base_storage::BaseStorage{T}
    # other fields specific to AsymmetricStorage
    min_capacity_withdrawal::Float64 = 0.0
    max_capacity_withdrawal::Float64 = 100.0
    existing_capacity_withdrawal::Float64 = 0.0
    investment_cost_withdrawal::Float64 = 0.0
    fixed_om_cost_withdrawal::Float64 = 0.0
    _capacity_withdrawal::Array{VariableRef} = VariableRef[]
    _new_capacity_withdrawal::Array{VariableRef} = VariableRef[]
    _ret_capacity_withdrawal::Array{VariableRef} = VariableRef[]
end
# ctor for AsymmetricStorage
function AsymmetricStorage{T}(;kwargs...) where {T}
    base_fields = fieldnames(BaseResource)
    base_storage_fields = fieldnames(BaseStorage)
    base_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k in base_fields)
    base_storage_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k in base_storage_fields)
    AsymmetricStorage_kwargs = Dict{Symbol,Any}(k=>v for (k,v) in kwargs if k ∉ base_fields && k ∉ base_storage_fields)
    return AsymmetricStorage(base=BaseResource{T}(; base_kwargs...), 
                base_storage=BaseStorage{T}(; base_storage_kwargs...);
                AsymmetricStorage_kwargs...)
end

# Asymmetric Storage interface
existing_capacity_withdrawal(g::AsymmetricStorage) = g.existing_capacity_withdrawal;
new_capacity_withdrawal(g::AsymmetricStorage) = g._new_capacity_withdrawal[1];
ret_capacity_withdrawal(g::AsymmetricStorage) = g._ret_capacity_withdrawal[1];
capacity_withdrawal(g::AsymmetricStorage) = g._capacity_withdrawal[1];

# 

function add_planning_variables!(g::SymmetricStorage, model::JuMP.Model)

    g._new_capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vNEWCAP_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vRETCAP_$(commodity_type(g))_$(g.r_id)")]

    g._capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vCAP_$(commodity_type(g))_$(g.r_id)")]

    g._new_capacity_storage = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity_storage = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._capacity_storage = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    JuMP.@constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    JuMP.@constraint(model, capacity_storage(g) == new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g))

    if !g.can_expand
        fix(new_capacity(g), 0.0; force=true)
        fix(new_capacity_storage(g), 0.0; force=true)
    end

    if !g.can_retire
        fix(ret_capacity(g), 0.0; force=true)
        fix(ret_capacity_storage(g), 0.0; force=true)
    end

    return nothing

end

function add_planning_variables!(g::AsymmetricStorage, model::JuMP.Model)

    g._new_capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vNEWCAP_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vRETCAP_$(commodity_type(g))_$(g.r_id)")]

    g._capacity = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vCAP_$(commodity_type(g))_$(g.r_id)")]

    g._new_capacity_storage = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity_storage = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._capacity_storage = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._new_capacity_withdrawal = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vNEWCAPWDW_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity_withdrawal = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vRETCAPWDW_$(commodity_type(g))_$(g.r_id)")]

    g._capacity_withdrawal = [JuMP.@variable(model, lower_bound = 0.0, base_name = "vCAPWDW_$(commodity_type(g))_$(g.r_id)")]

    JuMP.@constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    JuMP.@constraint(model, capacity_storage(g) == new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g))

    JuMP.@constraint(model, capacity_withdrawal(g) == new_capacity_withdrawal(g) - ret_capacity_withdrawal(g) + existing_capacity_withdrawal(g))

    if !g.can_expand
        fix(new_capacity(g), 0.0; force=true)
        fix(new_capacity_storage(g), 0.0; force=true)
        fix(new_capacity_withdrawal(g), 0.0; force=true)
    end

    if !g.can_retire
        fix(ret_capacity(g), 0.0; force=true)
        fix(ret_capacity_storage(g), 0.0; force=true)
        fix(ret_capacity_withdrawal(g), 0.0; force=true)
    end

    return nothing

end


function add_fixed_cost!(g::SymmetricStorage, model::JuMP.Model)

    model[:eFixedCost] += g.investment_cost * new_capacity(g) + g.fixed_om_cost * capacity(g)

    model[:eFixedCost] += g.investment_cost_storage * new_capacity_storage(g) + g.fixed_om_cost_storage * capacity_storage(g)

end

function add_operation_variables!(g::AbstractStorage, model::JuMP.Model)
    
    g._injection = JuMP.@variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vINJ_$(commodity_type(g))_$(g.r_id)")
    g._withdrawal = JuMP.@variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vWDW_$(commodity_type(g))_$(g.r_id)")
    g._storage_level = JuMP.@variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vSTOR_$(commodity_type(g))_$(g.r_id)")
    
end

function add_fixed_cost!(g::AsymmetricStorage, model::JuMP.Model)

    model[:eFixedCost] += g.investment_cost * new_capacity(g) + g.fixed_om_cost * capacity(g)

    model[:eFixedCost] += g.investment_cost_storage * new_capacity_storage(g) + g.fixed_om_cost_storage * capacity_storage(g)

    model[:eFixedCost] += g.investment_cost_withdrawal * new_capacity_withdrawal(g) + g.fixed_om_cost_withdrawal * capacity_withdrawal(g)

end

function add_variable_cost!(g::AbstractStorage, model::JuMP.Model)

    model[:eVariableCost] += g.variable_om_cost_withdrawal * sum(withdrawal(g))

end




