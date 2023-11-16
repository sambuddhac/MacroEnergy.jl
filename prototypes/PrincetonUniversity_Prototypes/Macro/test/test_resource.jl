module TestResource

using Macro
using Test


const test_inputs = (
    node = 1,
    r_id = 1,
    capacity_factor = rand(100),
    investment_cost = 85300.0,
    fixed_om_cost = 18760.0,
    price = rand(100),
    time_interval = 1:1:100,
    subperiods = [1:1:10],
)

function test_Resource_ctor()

    r = Resource{Electricity}(; test_inputs...)

    # Test that the BaseResource fields are inherited correctly 
    @test Macro.commodity_type(r) == Electricity
    @test Macro.existing_capacity(r) == 0.0
    @test Macro.can_expand(r) == true
    @test Macro.can_retire(r) == true
    @test Macro.node(r) == test_inputs.node
    @test Macro.resource_id(r) == test_inputs.r_id
    @test Macro.capacity_factor(r) == test_inputs.capacity_factor
    @test Macro.investment_cost(r) == test_inputs.investment_cost
    @test Macro.fixed_om_cost(r) == test_inputs.fixed_om_cost
    @test Macro.price(r) == test_inputs.price
    @test Macro.time_interval(r) == test_inputs.time_interval
    @test Macro.subperiods(r) == test_inputs.subperiods

    # Test that the VRE fields are set correctly
    return nothing
end

test_Resource_ctor()

end # module TestResource
