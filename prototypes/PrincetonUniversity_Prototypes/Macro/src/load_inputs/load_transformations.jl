function load_tedges(
    tedges_path::AbstractString,
    transformations_path::AbstractString,
    nodes::Dict{Symbol,Node},
)

    # load tnetwork topology and transformations
    df_edges = load_dataframe(tedges_path)
    df_transformations = load_dataframe(transformations_path)

    rename!(df_edges, Symbol.(lowercase.(names(df_edges))))
    rename!(df_transformations, Symbol.(lowercase.(names(df_transformations))))

    transformations_id = popat_col!(df_transformations, :id)

    # output: vector of transformations
    transformations = Vector{Transformation}(undef, length(eachrow(df_transformations)))

    # loop over dataframe rows and create a transformation for each row
    for (i, row) in enumerate(eachrow(df_transformations))
        id = transformations_id[i]

        df_edge = df_edges[df_edges.transformation.==id, :]

        # transformation is a vector of tedges
        tedges = Vector{TEdge}(undef, length(eachrow(df_edge)))
        for (edge_i, edge) in enumerate(eachrow(df_edge))
            start_node = nodes[Symbol(edge.node_in)]
            end_node = nodes[Symbol(edge.node_out)]
            edge_id = Symbol(edge.id)
            transformation_id = Symbol(edge.transformation)
            flow_direction = edge.flow_direction
            tedges[edge_i] =
                TEdge(edge_id, start_node, end_node, transformation_id, flow_direction)
        end
        transformations[i] = Transformation(; id = Symbol(id), tedges = tedges, row...)
    end

    return transformations
end
