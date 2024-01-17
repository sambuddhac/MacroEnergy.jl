include("test_nodes.jl")
include("test_networks.jl")

function test_compare_transformations(
    transformations_test::Vector{Transformation},
    transformations_true::Vector{Transformation},
)
    @test length(transformations_test) == length(transformations_true)
    for i in eachindex(transformations_test)
        compare_transformations(transformations_test[i], transformations_true[i])
    end
end

function compare_transformations(
    transformation_test::Transformation,
    transformation_true::Transformation,
)
    @test transformation_test.id == transformation_true.id
    @testset compare_tedges(transformation_test.tedges, transformation_true.tedges)
    @test transformation_test.num_edges == transformation_true.num_edges

    @test transformation_test.min_capacity == transformation_true.min_capacity
    @test transformation_test.max_capacity == transformation_true.max_capacity
    @test transformation_test.existing_capacity == transformation_true.existing_capacity
    @test transformation_test.can_expand == transformation_true.can_expand
    @test transformation_test.can_retire == transformation_true.can_retire
    @test transformation_test.investment_cost == transformation_true.investment_cost
    @test transformation_test.fixed_om_cost == transformation_true.fixed_om_cost
    @test transformation_test.variable_om_cost == transformation_true.variable_om_cost
    @test transformation_test.start_cost_per_mw == transformation_true.start_cost_per_mw
    @test transformation_test.ramp_up_percentage == transformation_true.ramp_up_percentage
    @test transformation_test.ramp_down_percentage ==
          transformation_true.ramp_down_percentage
    @test transformation_test.up_time == transformation_true.up_time
    @test transformation_test.down_time == transformation_true.down_time

    @test transformation_test.electricity_st == transformation_true.electricity_st
    @test transformation_test.ng_st == transformation_true.ng_st
    @test transformation_test.h2_st == transformation_true.h2_st
    @test transformation_test.min_output_elec == transformation_true.min_output_elec
    @test transformation_test.min_output_h2 == transformation_true.min_output_h2

    @test transformation_test.planning_vars == transformation_true.planning_vars
    @test transformation_test.operation_vars == transformation_true.operation_vars
    @test transformation_test.constraints == transformation_true.constraints broken = true
end
