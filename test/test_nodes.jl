function test_compare_nodes(nodes_test::Dict{Symbol,Node}, nodes_true::Dict{Symbol,Node})
    for node_id in keys(nodes_test)
        compare_nodes(nodes_test[node_id], nodes_true[node_id])
    end
end

function compare_nodes(node::Node, node_true::Node)
    @test node.id == node_true.id
    @test node.demand == node_true.demand
    ###@test node.fuel_price == node_true.fuel_price
    @test node.time_interval == node_true.time_interval
    @test node.max_nsd == node_true.max_nsd
    @test node.price_nsd == node_true.price_nsd
    @test node.operation_vars == node_true.operation_vars
    @test node.operation_expr == node_true.operation_expr
    @test node.constraints == node_true.constraints broken = true
end
