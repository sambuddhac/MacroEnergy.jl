function test_compare_storage(
    storages_test::Dict{DataType,Macro.Storage},
    storages_true::Dict{DataType,Macro.Storage},
)
    for storage_id in keys(storages_test)
        storage_test = storages_test[storage_id]
        storage_true = storages_true[storage_id]
        compare_storage(storage_test, storage_true)
    end
end

function compare_storage(storage_test::Macro.Storage, storage_true::Macro.Storage)
    for (s_true, s_test) in zip(storage_true, storage_test)
        compare_storage(s_test, s_true)
    end
end

function compare_storage(storage_test::AbstractStorage, storage_true::AbstractStorage)
    @test storage_test.id == storage_true.id
    @testset compare_nodes(storage_test.node, storage_true.node)
    @test storage_test.time_interval == storage_true.time_interval
    @test storage_test.subperiods == storage_true.subperiods
    @test storage_test.capacity_factor == storage_true.capacity_factor
    @test storage_test.min_capacity == storage_true.min_capacity
    @test storage_test.max_capacity == storage_true.max_capacity
    @test storage_test.min_capacity_storage == storage_true.min_capacity_storage
    @test storage_test.max_capacity_storage == storage_true.max_capacity_storage
    @test storage_test.existing_capacity == storage_true.existing_capacity
    @test storage_test.existing_capacity_storage == storage_true.existing_capacity_storage
    @test storage_test.can_expand == storage_true.can_expand
    @test storage_test.can_retire == storage_true.can_retire
    @test storage_test.investment_cost == storage_true.investment_cost
    @test storage_test.investment_cost_storage == storage_true.investment_cost_storage
    @test storage_test.investment_cost_charge == storage_true.investment_cost_charge
    @test storage_test.fixed_om_cost == storage_true.fixed_om_cost
    @test storage_test.fixed_om_cost_storage == storage_true.fixed_om_cost_storage
    @test storage_test.fixed_om_cost_charge == storage_true.fixed_om_cost_charge
    @test storage_test.variable_om_cost == storage_true.variable_om_cost
    @test storage_test.variable_om_cost_storage == storage_true.variable_om_cost_storage
    @test storage_test.variable_om_cost_charge == storage_true.variable_om_cost_charge
    @test storage_test.efficiency_charge == storage_true.efficiency_charge
    @test storage_test.efficiency_discharge == storage_true.efficiency_discharge
    @test storage_test.min_storage_level == storage_true.min_storage_level
    @test storage_test.min_duration == storage_true.min_duration
    @test storage_test.max_duration == storage_true.max_duration
    @test storage_test.self_discharge == storage_true.self_discharge
    @test storage_test.planning_vars == storage_true.planning_vars
    @test storage_test.operation_vars == storage_true.operation_vars
    @test storage_test.constraints == storage_true.constraints broken = true
end

function compare_storage(storage_test::AsymmetricStorage, storage_true::AsymmetricStorage)
    @testset begin
        @invoke compare_storage(
            storage_test::AbstractStorage,
            storage_true::AbstractStorage,
        )
    end
    @test storage_test.min_capacity_withdrawal == storage_true.min_capacity_withdrawal
    @test storage_test.max_capacity_withdrawal == storage_true.max_capacity_withdrawal
    @test storage_test.existing_capacity_withdrawal ==
          storage_true.existing_capacity_withdrawal
    @test storage_test.investment_cost_withdrawal == storage_true.investment_cost_withdrawal
    @test storage_test.fixed_om_cost_withdrawal == storage_true.fixed_om_cost_withdrawal
end
