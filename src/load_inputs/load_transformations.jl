using JSON3
using InteractiveUtils

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

function load_transformations_json(data_dir::AbstractString, macro_settings::NamedTuple)
    # Make a list of all the TransformationTypes
    t_types = transformation_types(Macro)
    # Make a list of all the .JSON files in the data directory
    files = filter(x -> endswith(x, ".json"), readdir(data_dir))
    # Make empty Dict of transformations 
    transformations = Dict{Symbol,Transformation}()
    # For each file, load the JSON, extract the transformation data
    # and make the transformation
    for file in files
        data = JSON3.read(joinpath(data_dir, file))
        load_transformations!(transformations, data, t_types, macro_settings)
    end
    return transformations
end

function load_transformations!(transformations::Dict{Symbol,Transformation}, data::JSON3.Object, t_types::Dict{Symbol, DataType}, macro_settings::NamedTuple)
    for (t_name, t_data) in data
        # Get the TransformationType.
        #=============================================
        The :type key is currently outside of the global and instance data
        so there can only be one TransformationType.
        We could change that, but it would mean different transformations
        sharing costs and / or lists of nodes, which would be odd.
        =============================================#
        sanitize_json!(t_data)
        t_type = t_types[Symbol(t_data[:type])]
        # Check if there are multiple instance_data inputs for this transformation
        if typeof(t_data[:instance]) == JSON3.Object
            # If only one, get the inputs, assign an ID, and make the transformation
            instance_data = transformation_instance_data(t_data[:global], t_data[:instance])
            haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = t_name
            instance_data[:id], _ = make_transformation_id(instance_id, transformations)
            transformations[instance_data[:id]] = Transformation{t_type}(instance_data, macro_settings)
        else
            # Otherwise, loop over the instance_data inputs and do the same for each
            counter = UInt8(0)
            for instance_data in t_data[:instance]
                counter += UInt8(1)
                instance_data = transformation_instance_data(t_data[:global], instance_data)
                haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = t_name
                instance_data[:id], counter = make_transformation_id(instance_id, transformations, counter)
                transformations[instance_data[:id]] = Transformation{t_type}(instance_data, macro_settings)
            end
        end
    end
end

function transformation_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::AbstractDict{Symbol,Any}, c_types::Dict{Symbol, DataType}=commodity_types(Macro))
    # Merge global and node data, with node data overwriting global data
    instance_data = merge(global_data, instance_data)
    # Convert the JSON3 Object to a Dict{Symbol, Any}
    instance_data[:edge_commodities] = Dict(instance_data[:edge_commodities])
    # Substitute the commodity types for the strings in the data
    instance_data[:time_interval] = c_types[Symbol(instance_data[:time_interval])]
    for (edge_name, commodity_name) in instance_data[:edge_commodities]
        instance_data[:edge_commodities][edge_name] = c_types[Symbol(commodity_name)]
    end
    return instance_data
end

function make_transformation_id(id::Symbol, transformations::Dict{Symbol,Transformation}, count::UInt8=UInt8(1))
    existing_ids = collect(keys(transformations))
    while Symbol(string(id, "_", count)) in existing_ids
        count += UInt8(1)
    end
    return Symbol(string(id, "_", count)), count
end

function all_subtypes(m::Module, type::Symbol)::Dict{Symbol, DataType}
    types = Dict{Symbol, DataType}()
    for type in subtypes(getfield(m,type))
        all_subtypes!(types, type)
    end
    return types
end

function all_subtypes!(types::Dict{Symbol, DataType}, type::DataType)
    types[Symbol(type)] = type
    if !isempty(subtypes(type))
        for subtype in subtypes(type)
            all_subtypes!(types, subtype)
        end
    end
    return nothing
end

function transformation_types(m::Module=Macro)
    return all_subtypes(m, :TransformationType)
end

function commodity_types(m::Module=Macro)
    return all_subtypes(m, :Commodity)
end

function sanitize_json!(data::JSON3.Object)
    required_keys = Symbol[
        :type,
    ]
    paired_keys = Dict{Symbol, Symbol}(
        :global => :instance
    )
    # If any required are missing, throw an error
    for key in required_keys
        if !haskey(data, key)
            error("Missing key: $key")
        end
    end
    # For each paired key, if one is missing, add an empty Dict{Symbol,Any}
    # If both are missing, throw an error
    for (key_1, key_2) in paired_keys
        key_1_missing = !haskey(data, key_1)
        key_2_missing = !haskey(data, key_2)
        if key_1_missing && !key_2_missing
            data[key_1] = Dict{Symbol, Any}()
        elseif !key_1_missing && key_2_missing
            data[key_2] = Dict{Symbol, Any}()
        elseif key_1_missing && key_2_missing
            error("Missing key: $key_1 or $key_2")
        end
    end
    return nothing
end

