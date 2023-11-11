Base.@kwdef mutable struct SymmetricStorage{T} <: AbstractStorage{T}
    node::Int64;
    r_id::Int64;
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = 100.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    existing_capacity::Float64 = 0.0
    existing_capacity_storage::Float64=0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0 
    efficiency_charge::Float64=1.0;
    efficiency_discharge::Float64=1.0
    self_discharge::Float64=0.0
    min_storage_level::Float64=0.0
    _capacity::Array{VariableRef}  = VariableRef[]
    _new_capacity::Array{VariableRef}  = VariableRef[]
    _ret_capacity::Array{VariableRef} = VariableRef[]
    _capacity_storage::Array{VariableRef}  = VariableRef[]
    _new_capacity_storage::Array{VariableRef}  = VariableRef[]
    _ret_capacity_storage::Array{VariableRef} = VariableRef[]
    _injection::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    _withdrawal::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    _storage_level::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    constraints::Vector{AbstractConstraint} = AbstractConstraint[] 
end

Base.@kwdef mutable struct AsymmetricStorage{T} <: AbstractStorage{T}
    node::Int64;
    r_id::Int64;
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = 100.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    min_capacity_withdrawal::Float64 = 0.0
    max_capacity_withdrawal::Float64 = 100.0
    existing_capacity::Float64 = 0.0
    existing_capacity_storage::Float64=0.0
    existing_capacity_withdrawal::Float64=0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    investment_cost_storage::Float64 = 0.0
    investment_cost_withdrawal::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    fixed_om_cost_withdrawal::Float64 = 0.0
    variable_om_cost_withdrawal::Float64 = 0.0 
    efficiency_charge::Float64=1.0;
    efficiency_discharge::Float64=1.0
    self_discharge::Float64=0.0
    min_storage_level::Float64=0.0
    _capacity::Array{VariableRef}  = VariableRef[]
    _new_capacity::Array{VariableRef}  = VariableRef[]
    _ret_capacity::Array{VariableRef} = VariableRef[]
    _capacity_storage::Array{VariableRef}  = VariableRef[]
    _new_capacity_storage::Array{VariableRef}  = VariableRef[]
    _ret_capacity_storage::Array{VariableRef} = VariableRef[]
    _capacity_withdrawal::Array{VariableRef}  = VariableRef[]
    _new_capacity_withdrawal::Array{VariableRef}  = VariableRef[]
    _ret_capacity_withdrawal::Array{VariableRef} = VariableRef[]
    _injection::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    _withdrawal::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    _storage_level::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], VariableRef[])
    constraints::Vector{AbstractConstraint} = AbstractConstraint[] 
end

existing_capacity_storage(g::AbstractStorage) = g.existing_capacity_storage;
new_capacity_storage(g::AbstractStorage) = g._new_capacity_storage[1];
ret_capacity_storage(g::AbstractStorage) = g._ret_capacity_storage[1];
capacity_storage(g::AbstractStorage) = g._capacity_storage[1];

withdrawal(g::AbstractStorage) = g._withdrawal;
storage_level(g::AbstractStorage) = g._storage_level;

existing_capacity_withdrawal(g::AsymmetricStorage) = g.existing_capacity_withdrawal;
new_capacity_withdrawal(g::AsymmetricStorage) = g._new_capacity_withdrawal[1];
ret_capacity_withdrawal(g::AsymmetricStorage) = g._ret_capacity_withdrawal[1];
capacity_withdrawal(g::AsymmetricStorage) = g._capacity_withdrawal[1];


function add_planning_variables!(g::SymmetricStorage,model::Model)

    g._new_capacity = [@variable(model,lower_bound=0.0,base_name="vNEWCAP_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity = [@variable(model,lower_bound=0.0,base_name="vRETCAP_$(commodity_type(g))_$(g.r_id)")]

    g._capacity = [@variable(model,lower_bound=0.0,base_name="vCAP_$(commodity_type(g))_$(g.r_id)")]

    g._new_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._capacity_storage = [@variable(model,lower_bound=0.0,base_name="vCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    @constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))
    
    @constraint(model, capacity_storage(g) == new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g))

    if !g.can_expand
        fix(new_capacity(g),0.0; force=true)
        fix(new_capacity_storage(g),0.0; force=true)
    end
    
    if !g.can_retire
        fix(ret_capacity(g),0.0; force=true)
        fix(ret_capacity_storage(g),0.0; force=true)
    end
    
    return nothing
    
end

function add_planning_variables!(g::AsymmetricStorage,model::Model)

    g._new_capacity = [@variable(model,lower_bound=0.0,base_name="vNEWCAP_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity = [@variable(model,lower_bound=0.0,base_name="vRETCAP_$(commodity_type(g))_$(g.r_id)")]

    g._capacity = [@variable(model,lower_bound=0.0,base_name="vCAP_$(commodity_type(g))_$(g.r_id)")]

    g._new_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vNEWCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vRETCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._capacity_storage = [@variable(model,lower_bound=0.0,base_name="vCAPSTOR_$(commodity_type(g))_$(g.r_id)")]

    g._new_capacity_withdrawal = [@variable(model,lower_bound=0.0,base_name="vNEWCAPWDW_$(commodity_type(g))_$(g.r_id)")]

    g._ret_capacity_withdrawal = [@variable(model,lower_bound=0.0,base_name="vRETCAPWDW_$(commodity_type(g))_$(g.r_id)")]

    g._capacity_withdrawal = [@variable(model,lower_bound=0.0,base_name="vCAPWDW_$(commodity_type(g))_$(g.r_id)")]

    @constraint(model, capacity(g) == new_capacity(g) - ret_capacity(g) + existing_capacity(g))

    @constraint(model, capacity_storage(g) == new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g))

    @constraint(model, capacity_withdrawal(g) == new_capacity_withdrawal(g) - ret_capacity_withdrawal(g) + existing_capacity_withdrawal(g))

    if !g.can_expand
        fix(new_capacity(g),0.0; force=true)
        fix(new_capacity_storage(g),0.0; force=true)
        fix(new_capacity_withdrawal(g),0.0; force=true)
    end
    
    if !g.can_retire
        fix(ret_capacity(g),0.0; force=true)
        fix(ret_capacity_storage(g),0.0; force=true)
        fix(ret_capacity_withdrawal(g),0.0; force=true)
    end

    return nothing
    
end


function add_fixed_cost!(g::SymmetricStorage,model::Model)

    model[:eFixedCost] += g.investment_cost*new_capacity(g) + g.fixed_om_cost*capacity(g);

    model[:eFixedCost] += g.investment_cost_storage*new_capacity_storage(g) + g.fixed_om_cost_storage*capacity_storage(g);
    
end


function add_fixed_cost!(g::AsymmetricStorage,model::Model)

    model[:eFixedCost] += g.investment_cost*new_capacity(g) + g.fixed_om_cost*capacity(g);

    model[:eFixedCost] += g.investment_cost_storage*new_capacity_storage(g) + g.fixed_om_cost_storage*capacity_storage(g);

    model[:eFixedCost] += g.investment_cost_withdrawal*new_capacity_withdrawal(g) + g.fixed_om_cost_withdrawal*capacity_withdrawal(g);
    
end

function add_operation_variables!(g::AbstractStorage,model::Model)

    g._injection = @variable(model,[t in time_interval(g)],lower_bound=0.0,base_name="vINJ_$(commodity_type(g))_$(g.r_id)")
    g._withdrawal = @variable(model,[t in time_interval(g)],lower_bound=0.0,base_name="vWDW_$(commodity_type(g))_$(g.r_id)")
    g._storage_level = @variable(model,[t in time_interval(g)],lower_bound=0.0,base_name="vSTOR_$(commodity_type(g))_$(g.r_id)")

end

function add_variable_cost!(g::AbstractStorage,model::Model)

    model[:eVariableCost] += g.variable_om_cost_withdrawal*sum(withdrawal(g))

end




