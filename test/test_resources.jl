module TestResource

using Macro
using Test


include("test_nodes.jl")

const test_inputs = (
    id = :Solar1,
    node = Macro.Node{Electricity}(;
        id = :Node_1,
        demand = zeros(10),
        time_interval = 1:10,
        fuel_price = zeros(10),
    ),
    capacity_factor = rand(100),
    investment_cost = 85300.0,
    fixed_om_cost = 18760.0,
    time_interval = 1:1:100,
    subperiods = [1:1:10],
)

function test_resource_ctor()

    r = Resource{Electricity}(; test_inputs...)

    # Test that the BaseResource fields are inherited correctly 
    @test Macro.commodity_type(r) == Electricity
    @test Macro.existing_capacity(r) == 0.0
    @test Macro.can_expand(r) == true
    @test Macro.can_retire(r) == true
    @test Macro.get_id(r) == test_inputs.id
    @test Macro.capacity_factor(r) == test_inputs.capacity_factor
    @test Macro.investment_cost(r) == test_inputs.investment_cost
    @test Macro.fixed_om_cost(r) == test_inputs.fixed_om_cost
    @test Macro.time_interval(r) == test_inputs.time_interval
    @test Macro.subperiods(r) == test_inputs.subperiods

    # Test that the VRE fields are set correctly
    return nothing
end

function test_compare_resources(
    resources_test::Dict{DataType,Vector{Resource}},
    resources_true::Dict{DataType,Vector{Resource}},
)
    for resource_id in keys(resources_test)
        compare_resources(resources_test[resource_id], resources_true[resource_id])
    end

    return nothing
end

function compare_resources(
    resources_test::Vector{Resource},
    resources_true::Vector{Resource},
)
    @test length(resources_test) == length(resources_true)
    for i in eachindex(resources_test)
        compare_resources(resources_test[i], resources_true[i])
    end

    return nothing
end

function compare_resources(resource_test::Resource, resource_true::Resource)
    @test resource_test.id == resource_true.id
    @testset compare_nodes(resource_test.node, resource_true.node)
    @test resource_test.capacity_factor == resource_true.capacity_factor
    @test resource_test.time_interval == resource_true.time_interval
    @test resource_test.subperiods == resource_true.subperiods
    @test resource_test.min_capacity == resource_true.min_capacity
    @test resource_test.max_capacity == resource_true.max_capacity
    @test resource_test.existing_capacity == resource_true.existing_capacity
    @test resource_test.can_expand == resource_true.can_expand
    @test resource_test.can_retire == resource_true.can_retire
    @test resource_test.investment_cost == resource_true.investment_cost
    @test resource_test.fixed_om_cost == resource_true.fixed_om_cost
    @test resource_test.variable_om_cost == resource_true.variable_om_cost
    @test resource_test.planning_vars == resource_true.planning_vars
    @test resource_test.operation_vars == resource_true.operation_vars
    @test resource_test.constraints == resource_true.constraints broken = true

    return nothing
end

test_resource_ctor()

end # module TestResource
