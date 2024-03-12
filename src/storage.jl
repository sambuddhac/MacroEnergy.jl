"""
    BaseStorage
This type defines the common fields of all storage resources.
"""
Base.@kwdef mutable struct BaseStorage{T<:Commodity}
    existing_capacity_storage::Float64 = 0.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = Inf
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0
    efficiency_withdrawal::Float64 = 1.0
    efficiency_injection::Float64 = 1.0
    min_storage_level::Float64 = 0.0
    storage_loss_percentage::Float64 = 0.0
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
variable_om_cost_withdrawal(g::AbstractStorage) = g.variable_om_cost_withdrawal;
investment_cost_storage(g::AbstractStorage) = g.investment_cost_storage;
fixed_om_cost_storage(g::AbstractStorage) = g.fixed_om_cost_storage;
storage_level(g::AbstractStorage) = g.operation_vars[:storage_level];

efficiency_withdrawal(g::AbstractStorage) = g.efficiency_withdrawal;
efficiency_injection(g::AbstractStorage) = g.efficiency_injection;
storage_loss_percentage(g::AbstractStorage) = g.storage_loss_percentage;

Base.@kwdef mutable struct SymmetricStorage{T} <: AbstractStorage{T}
    ### Fields without defaults
    node::Node{T}
    id::Symbol
    # price::Vector{Float64} # = zeros(length(time_interval_map[T]))
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}}
    #### Fields with defaults
    capacity_factor::Vector{Float64} = ones(length(time_interval))
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = Inf
    existing_capacity::Float64 = 0.0
    existing_capacity_storage::Float64 = 0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    investment_cost_storage::Float64 = 0.0
    investment_cost_withdrawal::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    fixed_om_cost_withdrawal::Float64 = 0.0
    variable_om_cost::Float64 = 0.0
    variable_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0
    efficiency_withdrawal::Float64 = 1.0
    efficiency_injection::Float64 = 1.0
    min_storage_level::Float64 = 0.0
    min_duration::Float64 = 1.0
    max_duration::Float64 = 10.0
    storage_loss_percentage::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} =Vector{AbstractTypeConstraint}()
end

Base.@kwdef mutable struct AsymmetricStorage{T} <: AbstractStorage{T}
    ### Fields without defaults
    node::Node{T}
    id::Symbol
    # price::Vector{Float64} # = zeros(length(time_interval_map[T]))
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}}
    #### Fields with defaults
    capacity_factor::Vector{Float64} = ones(length(time_interval))
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
    max_capacity_storage::Float64 = Inf
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0
    efficiency_withdrawal::Float64 = 1.0
    efficiency_injection::Float64 = 1.0
    min_storage_level::Float64 = 0.0
    storage_loss_percentage::Float64 = 0.0
    # other fields specific to AsymmetricStorage
    min_capacity_withdrawal::Float64 = 0.0
    max_capacity_withdrawal::Float64 = Inf
    existing_capacity_withdrawal::Float64 = 0.0
    investment_cost_withdrawal::Float64 = 0.0
    fixed_om_cost_withdrawal::Float64 = 0.0
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end

# Asymmetric Storage interface
existing_capacity_withdrawal(g::AsymmetricStorage) = g.existing_capacity_withdrawal;
new_capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:new_capacity_withdrawal];
ret_capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:ret_capacity_withdrawal];
capacity_withdrawal(g::AsymmetricStorage) = g.planning_vars[:capacity_withdrawal];
investment_cost_withdrawal(g::AsymmetricStorage) = g.investment_cost_withdrawal;
fixed_om_cost_withdrawal(g::AsymmetricStorage) = g.fixed_om_cost_withdrawal;

struct Storage
    s::Array{SymmetricStorage}
    a::Array{AsymmetricStorage}
end
Storage() = Storage(SymmetricStorage[], AsymmetricStorage[])
Symmetric(s::Storage) = s.s
Asymmetric(s::Storage) = s.a

function Base.iterate(s::Storage)
    length(s.s) > 0 && return iterate(s.s)
    length(s.a) > 0 && return iterate(s.a)
    return nothing
end
function Base.iterate(s::Storage, state)
    (length(s.s) > 0) && (state ≤ length(s.s)) && return iterate(s.s, state)    # iterate over s.s
    (length(s.a) > 0) &&
        (state ≤ length(s.s) + length(s.a)) &&
        return (s.a[state-length(s.s)], state + 1)    # iterate over s.a
    return nothing
end
Base.length(s::Storage) = length(s.s) + length(s.a)


function add_planning_variables!(g::SymmetricStorage, model::Model)

    g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(g.id)"
    )

    g.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(g.id)"
    )

    g.planning_vars[:capacity] =
        @variable(model, lower_bound = 0.0, base_name = "vCAP_$(g.id)")

    g.planning_vars[:new_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAPSTOR_$(g.id)"
    )

    g.planning_vars[:ret_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAPSTOR_$(g.id)"
    )

    g.planning_vars[:capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPSTOR_$(g.id)"
    )

    @constraint(
        model,
        capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g)
    )

    @constraint(
        model,
        capacity_storage(g) ==
        new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g)
    )

    
    @constraint(model, ret_capacity(g) <= existing_capacity(g))

    @constraint(model, ret_capacity_storage(g) <= existing_capacity_storage(g))

    if !g.can_expand
        fix(new_capacity(g), 0.0; force = true)
        fix(new_capacity_storage(g), 0.0; force = true)
    else
        add_to_expression!(model[:eFixedCost],investment_cost(g), new_capacity(g)) 
        add_to_expression!(model[:eFixedCost],investment_cost_storage(g), new_capacity_storage(g)) 
    end

    if !g.can_retire
        fix(ret_capacity(g), 0.0; force = true)
        fix(ret_capacity_storage(g), 0.0; force = true)
    end

    if fixed_om_cost(g)>0
        add_to_expression!(model[:eFixedCost],fixed_om_cost(g), capacity(g))
    end

    if fixed_om_cost_storage(g)>0
        add_to_expression!(model[:eFixedCost],fixed_om_cost_storage(g), capacity_storage(g))
    end

    return nothing

end

function add_planning_variables!(g::AsymmetricStorage, model::Model)

    g.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAP_$(g.id)"
    )

    g.planning_vars[:ret_capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAP_$(g.id)"
    )

    g.planning_vars[:capacity] =
        @variable(model, lower_bound = 0.0, base_name = "vCAP_$(g.id)")

    g.planning_vars[:new_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAPSTOR_$(g.id)"
    )

    g.planning_vars[:ret_capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAPSTOR_$(g.id)"
    )

    g.planning_vars[:capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPSTOR_$(g.id)"
    )

    g.planning_vars[:new_capacity_withdrawal] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vNEWCAPWDW_$(g.id)"
    )

    g.planning_vars[:ret_capacity_withdrawal] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vRETCAPWDW_$(g.id)"
    )

    g.planning_vars[:capacity_withdrawal] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPWDW_$(g.id)"
    )

    @constraint(
        model,
        capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g)
    )

    @constraint(
        model,
        capacity_storage(g) ==
        new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g)
    )

    @constraint(
        model,
        capacity_withdrawal(g) ==
        new_capacity_withdrawal(g) - ret_capacity_withdrawal(g) +
        existing_capacity_withdrawal(g)
    )

    @constraint(model, ret_capacity(g) <= existing_capacity(g))

    @constraint(model, ret_capacity_storage(g) <= existing_capacity_storage(g))

    @constraint(model, ret_capacity_withdrawal(g) <= existing_capacity_withdrawal(g))

    if !g.can_expand
        fix(new_capacity(g), 0.0; force = true)
        fix(new_capacity_storage(g), 0.0; force = true)
        fix(new_capacity_withdrawal(g), 0.0; force = true)
    else
        add_to_expression!(model[:eFixedCost],investment_cost(g), new_capacity(g)) 
        add_to_expression!(model[:eFixedCost],investment_cost_storage(g), new_capacity_storage(g)) 
        add_to_expression!(model[:eFixedCost],investment_cost_withdrawal(g), new_capacity_withdrawal(g)) 
    end

    if !g.can_retire
        fix(ret_capacity(g), 0.0; force = true)
        fix(ret_capacity_storage(g), 0.0; force = true)
        fix(ret_capacity_withdrawal(g), 0.0; force = true)
    end

    if fixed_om_cost(g)>0
        add_to_expression!(model[:eFixedCost],fixed_om_cost(g), capacity(g))
    end

    if fixed_om_cost_storage(g)>0
        add_to_expression!(model[:eFixedCost],fixed_om_cost_storage(g), capacity_storage(g))
    end

    if fixed_om_cost_withdrawal(g)>0
        add_to_expression!(model[:eFixedCost],fixed_om_cost_withdrawal(g), capacity_withdrawal(g))
    end

    return nothing

end


function add_operation_variables!(g::AbstractStorage, model::Model)

    g.operation_vars[:injection] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vINJ_$(g.id)"
    )
    g.operation_vars[:withdrawal] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vWDW_$(g.id)"
    )
    g.operation_vars[:storage_level] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(g.id)"
    )

    time_subperiods = subperiods(g)

    aux_expr = @expression(model, [t in time_interval(g)], 0 * model[:vREF])
    for p in time_subperiods
        t_start = first(p)
        t_end = last(p)
        add_to_expression!(
            aux_expr[t_start],
            storage_level(g)[t_start] - (1 - storage_loss_percentage(g)) * storage_level(g)[t_end],
        )
        for t in p[2:end]
            add_to_expression!(
                aux_expr[t],
                storage_level(g)[t] - (1 - storage_loss_percentage(g)) * storage_level(g)[t-1],
            )
        end
    end

    @constraint(
        model,
        [t in time_interval(g)],
        aux_expr[t] ==  efficiency_withdrawal(g) * withdrawal(g)[t] - (1/efficiency_injection(g)) * injection(g)[t]
    )

    #delete(model,model[:aux_expr])
    #unregister(model, :aux_expr)
    
    n = node(g)

    for t in time_interval(g)

        add_to_expression!(
            n.operation_expr[:net_production][t],
            injection(g)[t] - withdrawal(g)[t],
        )

        if variable_om_cost(g)>0
            add_to_expression!(model[:eVariableCost], variable_om_cost(g), injection(g)[t])
        end

        if variable_om_cost_withdrawal(g)>0
            add_to_expression!(model[:eVariableCost], variable_om_cost_withdrawal(g), withdrawal(g)[t])
        end
        
    end

    return nothing


end


function add_model_constraint!(
    ct::StorageCapacityConstraint,
    g::AbstractStorage,
    model::Model,
)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        storage_level(g)[t] <= capacity_storage(g)
    )

end


function add_model_constraint!(
    ct::WithdrawalCapacityConstraint,
    g::AsymmetricStorage,
    model::Model,
)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        withdrawal(g)[t] <= capacity_withdrawal(g)
    )

end

function add_model_constraint!(
    ct::MinStorageDurationConstraint,
    g::AbstractStorage,
    model::Model,
)

    ct.constraint_ref =
        @constraint(model, capacity_storage(g) >= g.min_duration * capacity(g))

end

function add_model_constraint!(
    ct::MaxStorageDurationConstraint,
    g::AbstractStorage,
    model::Model,
)

    ct.constraint_ref =
        @constraint(model, capacity_storage(g) <= g.max_duration * capacity(g))

end