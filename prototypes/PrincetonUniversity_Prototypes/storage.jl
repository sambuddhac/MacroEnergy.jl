Base.@kwdef mutable struct SymmetricStorage{T} <: AbstractStorage{T}
    Node::Int64;
    R_ID::Int64;
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = 100.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    existing_capacity::Float64 = 0.0
    existing_capacity_storage::Float64=0.0
    policy_membership::Vector{String} = [""]
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
    _injection::Array{VariableRef} = Array{VariableRef}(undef,time_resolution_map[T])
    _withdrawal::Array{VariableRef} = Array{VariableRef}(undef,time_resolution_map[T])
    _storage_level::Array{VariableRef} = Array{VariableRef}(undef,time_resolution_map[T])
end

Base.@kwdef mutable struct AsymmetricStorage{T} <: AbstractStorage{T}
    Node::Int64;
    R_ID::Int64;
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = 100.0
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = 100.0
    min_capacity_withdrawal::Float64 = 0.0
    max_capacity_withdrawal::Float64 = 100.0
    existing_capacity::Float64 = 0.0
    existing_capacity_storage::Float64=0.0
    existing_capacityy_withdrawal::Float64=0.0
    policy_membership::Vector{String} = [""]
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
    _injection::Array{VariableRef} = Array{VariableRef}(undef,time_resolution_map[T])
    _withdrawal::Array{VariableRef} = Array{VariableRef}(undef,time_resolution_map[T])
    _storage_level::Array{VariableRef} = Array{VariableRef}(undef,time_resolution_map[T])
end


new_capacity_storage(g::AbstractStorage) = g._new_capacity_storage[1];
ret_capacity_storage(g::AbstractStorage) = g._ret_capacity_storage[1];
capacity_storage(g::AbstractStorage) = g._capacity_storage[1];
withdrawal(g::AbstractStorage) = g._withdrawal;
existing_capacity_storage(g::AbstractStorage) = g.existing_capacity_withdrawal;

new_capacity_withdrawal(g::AsymmetricStorage) = g._new_capacity_withdrawal[1];
ret_capacity_withdrawal(g::AsymmetricStorage) = g._ret_capacity_withdrawal[1];
capacity_withdrawal(g::AsymmetricStorage) = g._capacity_withdrawal[1];
existing_capacity_withdrawal(g::AsymmetricStorage) = g.existing_capacity_withdrawal;


function add_capacity_variables!(g::SymmetricStorage,model::Model)

    g._new_capacity = [@variable(model,lower_bound=0.0,base_name="vNEWCAP_$(resource_type(g))_$(g.R_ID)")]

    g._ret_capacity = [@variable(model,lower_bound=0.0,base_name="vRETCAP_$(resource_type(g))_$(g.R_ID)")]

    g._capacity = [@variable(model,lower_bound=0.0,base_name="vCAP_$(resource_type(g))_$(g.R_ID)")]

    g._new_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vNEWCAPSTOR_$(resource_type(g))_$(g.R_ID)")]

    g._ret_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vRETCAPSTOR_$(resource_type(g))_$(g.R_ID)")]

    g._capacity_storage = [@variable(model,lower_bound=0.0,base_name="vCAPSTOR_$(resource_type(g))_$(g.R_ID)")]

    
    return nothing
    
end

function add_capacity_variables!(g::AsymmetricStorage,model::Model)

    g._new_capacity = [@variable(model,lower_bound=0.0,base_name="vNEWCAP_$(resource_type(g))_$(g.R_ID)")]

    g._ret_capacity = [@variable(model,lower_bound=0.0,base_name="vRETCAP_$(resource_type(g))_$(g.R_ID)")]

    g._capacity = [@variable(model,lower_bound=0.0,base_name="vCAP_$(resource_type(g))_$(g.R_ID)")]

    g._new_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vNEWCAPSTOR_$(resource_type(g))_$(g.R_ID)")]

    g._ret_capacity_storage = [@variable(model,lower_bound=0.0,base_name="vRETCAPSTOR_$(resource_type(g))_$(g.R_ID)")]

    g._capacity_storage = [@variable(model,lower_bound=0.0,base_name="vCAPSTOR_$(resource_type(g))_$(g.R_ID)")]

    g._new_capacity_withdrawal = [@variable(model,lower_bound=0.0,base_name="vNEWCAPWDW_$(resource_type(g))_$(g.R_ID)")]

    g._ret_capacity_withdrawal = [@variable(model,lower_bound=0.0,base_name="vRETCAPWDW_$(resource_type(g))_$(g.R_ID)")]

    g._capacity_withdrawal = [@variable(model,lower_bound=0.0,base_name="vCAPWDW_$(resource_type(g))_$(g.R_ID)")]

    return nothing
    
end


function add_fixed_costs!(g::SymmetricStorage,model::Model)

    model[:eFixedCost] += g.investment_cost*new_capacity(g) + g.fixed_om_cost*capacity(g);

    model[:eFixedCost] += g.investment_cost_storage*new_capacity_storage(g) + g.fixed_om_cost_storage*capacity_storage(g);
    
end


function add_fixed_costs!(g::AsymmetricStorage,model::Model)

    model[:eFixedCost] += g.investment_cost*new_capacity(g) + g.fixed_om_cost*capacity(g);

    model[:eFixedCost] += g.investment_cost_storage*new_capacity_storage(g) + g.fixed_om_cost_storage*capacity_storage(g);

    model[:eFixedCost] += g.investment_cost_withdrawal*new_capacity_withdrawal(g) + g.fixed_om_cost_withdrawal*capacity_withdrawal(g);
    
end
