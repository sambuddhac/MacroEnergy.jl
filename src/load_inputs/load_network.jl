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
    #dict_fuel_prices = load_timeseries(fuel_prices_path, time_interval)

    rename!(df_nodes, Symbol.(lowercase.(names(df_nodes))))
    adjust_cols_types!(df_nodes)

    nodes_ids = Symbol.(popat_col!(df_nodes, :id))

    # output: dictionary of nodes
    nodes = Dict{Symbol,Node}()

    # loop over dataframe rows and create a node for each row with demand and fuel prices
    for (i, row) in enumerate(eachrow(df_nodes))
        id = nodes_ids[i]
        demand = id ∈ keys(dict_demand) ? dict_demand[id] : zeros(length(time_interval))
        # fuel_price =
        #     id ∈ keys(dict_fuel_prices) ? dict_fuel_prices[id] :
        #     zeros(length(time_interval))
        nodes[id] = Node{commodity}(;
            id = id,
            demand = demand,
            #fuel_price = fuel_price,
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

function load_edges_json(data_dir::AbstractString, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    commodities = commodity_types()
    # Make a list of all the .JSON files in the data directory
    # files = filter(x -> endswith(x, ".json"), readdir(data_dir))
    files = ["edges.json"]
    # Make an empty dictionary of edges
    edges = Dict{Symbol, Edge}()
    for file in files
        data = JSON3.read(joinpath(data_dir, file))
        load_edges!(edges, data, commodities, time_data, nodes)
    end
    return edges
end

function load_edges!(edges::Dict{Symbol, Edge}, data::AbstractDict{Symbol,Any}, commodity_types::Dict{Symbol,DataType}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    for (e_name, e_data) in data
        sanitize_json!(e_data)
        e_type = commodity_types[Symbol(e_data[:type])]
        if typeof(e_data[:instance]) == JSON3.Object
            # Only one instance
            instance_data = edge_instance_data(e_data[:global], e_data[:instance])
            haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = e_name
            instance_data[:id], _ = make_edge_id(instance_id, edges)
            start_node = nodes[Symbol(instance_data[:start_node_id])]
            end_node = nodes[Symbol(instance_data[:end_node_id])]
            edges[instance_data[:id]] = Edge(instance_data, time_data, e_type, node_start, node_end)
        else
            # Multiple instances
            # Note, the edge instance data has a different structures
            # than the transformation data.
            for (instance_idx, instance_data) in enumerate(e_data[:instance])
                instance_data = edge_instance_data(e_data[:global], instance_data)
                haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_edge_name(instance_idx, e_name)
                instance_data[:id], _ = make_edge_id(instance_id, edges)
                start_node = nodes[Symbol(instance_data[:start_node_id])]
                end_node = nodes[Symbol(instance_data[:end_node_id])]
                edges[instance_data[:id]] = Edge(instance_data, time_data, e_type, start_node, end_node)
            end
        end
    end
end

function default_edge_name(instance_name::T, e_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string(instance_name, "_", e_name))
end

function default_edge_name(instance_idx::Int, e_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string("z", instance_idx, "_", e_name))
end

function edge_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::T) where T<:AbstractDict{Symbol,Any}
    instance_data = merge(global_data, instance_data)
    return instance_data
end

function edge_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::T) where T<:Dict{Symbol,Any}
    instance_data = merge(global_data, instance_data)
    return instance_data
end

function make_edge_id(id::Symbol, edges::Dict{Symbol, Edge}, count::UInt8=UInt8(1))
    existing_ids = collect(keys(edges))
    # Unlike the transformations, we won't add a count by default
    if !(id in existing_ids)
        return id, count
    end
    # Otherwise, keep incrementing the count till we find a unique ID
    while Symbol(string(id, "_", count)) in existing_ids
        count += UInt8(1)
    end
    return Symbol(string(id, "_", count)), count
end

function load_nodes_json(data_dir::AbstractString, time_data::Dict{Symbol,TimeData})
    commodities = commodity_types()
    # Make a list of all the .JSON files in the data directory
    # files = filter(x -> endswith(x, ".json"), readdir(data_dir))
    files = ["nodes.json"]
    # Make an empty dictionary of nodes
    nodes = Dict{Symbol, Node}()
    for file in files
        data = JSON3.read(joinpath(data_dir, file))
        load_nodes!(nodes, data, commodities, time_data)
    end
    return nodes
end

function load_nodes!(nodes::Dict{Symbol, Node}, data::AbstractDict{Symbol,Any}, commodity_types::Dict{Symbol,DataType}, time_data::Dict{Symbol,TimeData})
    for (n_name, n_data) in data
        sanitize_json!(n_data)
        n_type = commodity_types[Symbol(n_data[:type])]
        if typeof(n_data[:instance]) == JSON3.Object
            # Only one instance
            instance_data = node_instance_data(n_data[:global], n_data[:instance])
            haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = n_name
            instance_data[:id], _ = make_node_id(instance_id, nodes)
            nodes[instance_data[:id]] = Node(instance_data, time_data, n_type)
        else
            # Multiple instances
            # Note, the node instance data has a different structures
            # than the transformation data.
            for (instance_idx, instance_data) in enumerate(n_data[:instance])
                instance_data = node_instance_data(n_data[:global], instance_data)
                haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_node_name(instance_idx, n_name)
                instance_data[:id], _ = make_node_id(instance_id, nodes)
                nodes[instance_data[:id]] = Node(instance_data, time_data, n_type)
            end
        end
    end
end

function default_node_name(instance_name::T, n_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string(instance_name, "_", n_name))
end

function default_node_name(instance_idx::Int, n_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string("z", instance_idx, "_", n_name))
end

function node_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::T) where T<:AbstractDict{Symbol,Any}
    instance_data = merge(global_data, instance_data)
    return instance_data
end

function node_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::T) where T<:Dict{Symbol,Any}
    instance_data = merge(global_data, instance_data)
    return instance_data
end


function make_node_id(id::Symbol, nodes::Dict{Symbol, Node}, count::UInt8=UInt8(1))
    existing_ids = collect(keys(nodes))
    # Unlike the transformations, we won't add a count by default
    if !(id in existing_ids)
        return id, count
    end
    # Otherwise, keep incrementing the count till we find a unique ID
    while Symbol(string(id, "_", count)) in existing_ids
        count += UInt8(1)
    end
    return Symbol(string(id, "_", count)), count
end
