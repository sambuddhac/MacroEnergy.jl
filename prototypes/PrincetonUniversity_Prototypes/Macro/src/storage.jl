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

# Storage interface
existing_capacity_storage(g::AbstractStorage) = g.existing_capacity_storage;
new_capacity_storage(g::AbstractStorage) = g.planning_vars[:new_capacity_storage];
ret_capacity_storage(g::AbstractStorage) = g.planning_vars[:ret_capacity_storage];
capacity_storage(g::AbstractStorage) = g.planning_vars[:capacity_storage];
withdrawal(g::AbstractStorage) = g.operation_vars[:withdrawal];
storage_level(g::AbstractStorage) = g.operation_vars[:storage_level];

efficiency_charge(g::AbstractStorage) = g.efficiency_charge;
efficiency_discharge(g::AbstractStorage) = g.efficiency_discharge;
self_discharge(g::AbstractStorage) = g.self_discharge;

Base.@kwdef mutable struct SymmetricStorage{T} <: AbstractStorage{T}
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
    existing_capacity_storage::Float64 = 0.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0
    efficiency_charge::Float64 = 1.0
    efficiency_discharge::Float64 = 1.0
    min_storage_level::Float64 = 0.0
    self_discharge::Float64 = 0.0
    constraints ::Vector{AbstractTypeConstraint}=[CapacityConstraint{T}(),StorageCapacityConstraint{T}()]
end

Base.@kwdef mutable struct AsymmetricStorage{T} <: AbstractStorage{T}
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
    existing_capacity_storage::Float64 = 0.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0
    efficiency_charge::Float64 = 1.0
    efficiency_discharge::Float64 = 1.0
    min_storage_level::Float64 = 0.0
    self_discharge::Float64 = 0.0
    # other fields specific to AsymmetricStorage
    min_capacity_withdrawal::Float64 = 0.0
    max_capacity_withdrawal::Float64 = 100.0
    existing_capacity_withdrawal::Float64 = 0.0
    investment_cost_withdrawal::Float64 = 0.0
    fixed_om_cost_withdrawal::Float64 = 0.0
    constraints ::Vector{AbstractTypeConstraint}=[CapacityConstraint{T}(),StorageCapacityConstraint{T}(),WithdrawalCapacityConstraint{T}()]
end

# Asymmetric Storage interface
existing_capacity_withdrawal(g::AsymmetricStorage) = g.existing_capacity_withdrawal;
new_capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:new_capacity_withdrawal];
ret_capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:ret_capacity_withdrawal];
capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:capacity_withdrawal];




