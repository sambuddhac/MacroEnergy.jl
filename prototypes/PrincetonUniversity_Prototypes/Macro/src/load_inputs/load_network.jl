function load_nodes(
    nodes_path::AbstractString,
    demand_path::AbstractString,
    fuel_prices_path::AbstractString,
    commodity,
    time_interval::StepRange{Int64,Int64},
)

    df_nodes = load_dataframe(nodes_path)

    # load demand data
    dict_demand = load_timeseries(demand_path, time_interval)
    # load fuel prices data
    dict_fuel_prices = load_timeseries(fuel_prices_path, time_interval)

    rename!(df_nodes, Symbol.(lowercase.(names(df_nodes))))
    adjust_cols_types!(df_nodes)

    nodes_ids = Symbol.(popat_col!(df_nodes, :id))

    # output: dictionary of nodes
    nodes = Dict{Symbol,Node}()

    # loop over dataframe rows and create a node for each row with demand and fuel prices
    for (i, row) in enumerate(eachrow(df_nodes))
        id = nodes_ids[i]
        demand = id ∈ keys(dict_demand) ? dict_demand[id] : zeros(length(time_interval))
        fuel_price =
            id ∈ keys(dict_fuel_prices) ? dict_fuel_prices[id] :
            zeros(length(time_interval))
        nodes[id] = Node{commodity}(;
            id = id,
            demand = demand,
            fuel_price = fuel_price,
            time_interval = time_interval,
            row...,
        )
    end

    return nodes
end


function load_network(
    network_path::AbstractString,
    nodes::Dict{Symbol,Node},
    commodity,
    time_interval::StepRange{Int64,Int64},
)

    df_network = load_dataframe(network_path)

    rename!(df_network, Symbol.(lowercase.(names(df_network))))

    popat_col!(df_network, :id)
    start_nodes_id = Symbol.(popat_col!(df_network, :start_node))
    end_nodes_id = Symbol.(popat_col!(df_network, :end_node))

    # output: vector of edges
    network = Vector{Edge}(undef, length(eachrow(df_network)))

    # loop over dataframe rows and create an edge for each row
    for (i, row) in enumerate(eachrow(df_network))

        start_node_id = start_nodes_id[i]
        start_node = nodes[start_node_id]

        end_node_id = end_nodes_id[i]
        end_node = nodes[end_node_id]

        network[i] = Edge{commodity}(;
            start_node = start_node,
            end_node = end_node,
            time_interval = time_interval,
            row...,
        )
    end

    return network
end
