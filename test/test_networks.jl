include("test_nodes.jl")

function test_compare_networks(
    networks_test::Dict{DataType,Any},
    networks_true::Dict{DataType,Any},
)
    for commodity in keys(networks_test)
        compare_networks(networks_test[commodity], networks_true[commodity])
    end
end

function compare_networks(network_test::Vector{Edge}, network_true::Vector{Edge})
    @test length(network_test) == length(network_true)
    for i in eachindex(network_test)
        compare_edges(network_test[i], network_true[i])
    end
end

function compare_edges(edge::Edge, edge_true::Edge)
    @test edge.time_interval == edge_true.time_interval
    @testset compare_nodes(edge.start_node, edge_true.start_node)
    @testset compare_nodes(edge.end_node, edge_true.end_node)
    @test edge.existing_capacity == edge_true.existing_capacity
    @test edge.unidirectional == edge_true.unidirectional
    @test edge.max_line_flow_capacity == edge_true.max_line_flow_capacity
    @test edge.max_line_reinforcement == edge_true.max_line_reinforcement
    @test edge.line_reinforcement_cost == edge_true.line_reinforcement_cost
    @test edge.num_lines_existing == edge_true.num_lines_existing
    @test edge.can_expand == edge_true.can_expand
    @test edge.max_num_lines_expanded == edge_true.max_num_lines_expanded
    @test edge.investment_cost == edge_true.investment_cost
    @test edge.op_cost == edge_true.op_cost
    @test edge.distance == edge_true.distance
    @test edge.line_loss_percentage == edge_true.line_loss_percentage
    @test edge.planning_vars == edge_true.planning_vars
    @test edge.operation_vars == edge_true.operation_vars
    @test edge.constraints == edge_true.constraints broken = true
end

function compare_tedges(tedges_test::Vector{TEdge}, tedges_true::Vector{TEdge})
    @test length(tedges_test) == length(tedges_true)
    for i in eachindex(tedges_test)
        compare_tedges(tedges_test[i], tedges_true[i])
    end
end

function compare_tedges(tedge_test::TEdge, tedge_true::TEdge)
    @test tedge_test.id == tedge_true.id
    @testset compare_nodes(tedge_test.start_node, tedge_true.start_node)
    @testset compare_nodes(tedge_test.end_node, tedge_true.end_node)
    @test tedge_test.transformation == tedge_true.transformation
    @test tedge_test.flow_direction == tedge_true.flow_direction
end
