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
    capacity_factor::Vector{Float64}  # = ones(length(time_interval_map[T]))
    price::Vector{Float64} # = zeros(length(time_interval_map[T]))
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
    existing_capacity_storage::Float64 = 0.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0
    efficiency_charge::Float64 = 1.0
    efficiency_discharge::Float64 = 1.0
    min_storage_level::Float64 = 0.0
    min_duration::Float64=1.0
    max_duration::Float64=10.0
    self_discharge::Float64 = 0.0
    constraints::Vector{AbstractTypeConstraint} =
        [CapacityConstraint{T}(), StorageCapacityConstraint{T}()]
end

Base.@kwdef mutable struct AsymmetricStorage{T} <: AbstractStorage{T}
    ### Fields without defaults
    node::Int64
    r_id::Int64
    capacity_factor::Vector{Float64}  # = ones(length(time_interval_map[T]))
    price::Vector{Float64} # = zeros(length(time_interval_map[T]))
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
    constraints::Vector{AbstractTypeConstraint} = [
        CapacityConstraint{T}(),
        StorageCapacityConstraint{T}(),
        WithdrawalCapacityConstraint{T}(),
    ]
end

# Asymmetric Storage interface
existing_capacity_withdrawal(g::AsymmetricStorage) = g.existing_capacity_withdrawal;
new_capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:new_capacity_withdrawal];
ret_capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:ret_capacity_withdrawal];
capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:capacity_withdrawal];



function add_planning_variables!(g::SymmetricStorage, model::Model)
   
    g.planning_vars[:new_capacity] = @variable(model, lower_bound = 0.0, base_name = "vNEWCAP_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:ret_capacity] = @variable(model, lower_bound = 0.0, base_name = "vRETCAP_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:capacity] = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:new_capacity_storage] = @variable(model, lower_bound = 0.0, base_name = "vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:ret_capacity_storage] = @variable(model, lower_bound = 0.0, base_name = "vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:capacity_storage] = @variable(model, lower_bound = 0.0, base_name = "vCAPSTOR_$(commodity_type(g))_$(g.r_id)")

    @constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    @constraint(model, capacity_storage(g) == new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g))

    if !g.can_expand
        fix(new_capacity_storage(g), 0.0; force=true)
    end

    if !g.can_retire
        fix(ret_capacity_storage(g), 0.0; force=true)
    end

    @constraint(model,ret_capacity(g)<=existing_capacity(g))

    @constraint(model,ret_capacity_storage(g)<=existing_capacity_storage(g))
   

    return nothing

end

function add_planning_variables!(g::AsymmetricStorage, model::Model)

    g.planning_vars[:new_capacity] = @variable(model, lower_bound = 0.0, base_name = "vNEWCAP_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:ret_capacity] = @variable(model, lower_bound = 0.0, base_name = "vRETCAP_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:capacity] = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:new_capacity_storage] = @variable(model, lower_bound = 0.0, base_name = "vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:ret_capacity_storage] = @variable(model, lower_bound = 0.0, base_name = "vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:capacity_storage] = @variable(model, lower_bound = 0.0, base_name = "vCAPSTOR_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:new_capacity_withdrawal] = @variable(model, lower_bound = 0.0, base_name = "vNEWCAPWDW_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:ret_capacity_withdrawal] = @variable(model, lower_bound = 0.0, base_name = "vRETCAPWDW_$(commodity_type(g))_$(g.r_id)")

    g.planning_vars[:capacity_withdrawal] = @variable(model, lower_bound = 0.0, base_name = "vCAPWDW_$(commodity_type(g))_$(g.r_id)")

    @constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    @constraint(model, capacity_storage(g) == new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g))

    @constraint(model, capacity_withdrawal(g) == new_capacity_withdrawal(g)- ret_capacity_withdrawal(g) + existing_capacity_withdrawal(g))

    @constraint(model,ret_capacity(g)<=existing_capacity(g))
    
    @constraint(model,ret_capacity_storage(g)<=existing_capacity_storage(g))

    @constraint(model,ret_capacity_withdrawal(g)<=existing_capacity_withdrawal(g))

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


function add_operation_variables!(g::AbstractStorage, nodes::Vector{AbstractNode},  model::Model)
    
    g.operation_vars[:injection] = @variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vINJ_$(commodity_type(g))_$(g.r_id)")
    g.operation_vars[:withdrawal] = @variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vWDW_$(commodity_type(g))_$(g.r_id)")
    g.operation_vars[:storage_level] = @variable(model, [t in time_interval(g)], lower_bound = 0.0, base_name = "vSTOR_$(commodity_type(g))_$(g.r_id)")

    time_subperiods = subperiods(g);
    
    aux_expr = @expression(model,[t in time_interval(g)],0*model[:vREF])
    for p in time_subperiods
        t_start = first(p);
        t_end = last(p);
        add_to_expression!(aux_expr[t_start], storage_level(g)[t_start] - (1-self_discharge(g))*storage_level(g)[t_end]);
        for t in p[2:end]
            add_to_expression!(aux_expr[t], storage_level(g)[t]  - (1-self_discharge(g))*storage_level(g)[t-1]);
        end
    end
  
    @constraint(model,[t in time_interval(g)], aux_expr[t] == efficiency_discharge(g)*injection(g)[t] - efficiency_charge(g)*withdrawal(g)[t]);

    unregister(model,:aux_expr)

    n = map_resource_to_node(g,nodes);

    for t in time_interval(g)
        add_to_expression!(n.operation_expr[:net_energy_production][t], injection(g)[t]-withdrawal(g)[t])
    end

    return nothing


end

