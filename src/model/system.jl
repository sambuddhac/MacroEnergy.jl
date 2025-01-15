mutable struct System
    data_dirpath::String
    settings::NamedTuple
    commodities::Dict{Symbol,DataType}
    time_data::Dict{Symbol,TimeData}
    assets::Vector{AbstractAsset}
    locations::Vector{Node}
end

asset_ids(system::System) = map(x -> x.id, system.assets)
location_ids(system::System) = map(x -> x.id, system.locations)

function set_data_dirpath!(system::System, data_dirpath::String)
    system.data_dirpath = data_dirpath
end

function add!(system::System, asset::AbstractAsset)
    push!(system.assets, asset)
end

function add!(system::System, location::Node)
    push!(system.locations, location)
end

function empty_system(data_dirpath::String)
    @debug("Creating empty system, with data relative path set to $data_dirpath")
    return System(
        data_dirpath,
        NamedTuple(),
        Dict{Symbol,DataType}(),
        Dict{Symbol,TimeData}(),
        [],
        [],
    )
end

function get_asset_by_id(system::System, id::Symbol)
    for asset in system.assets
        if asset.id == id
            return asset
        end
    end
    return nothing
end

function find_node(nodes_list::Vector{Node}, id::Symbol)
    for node in nodes_list
        if node.id == id
            return node
        end
    end
    error("Vertex $id not found")
    return nothing
end

# Function to extract all the nodes, edges, storages, and transformations from a system
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.
get_nodes(system::System) = system.locations
get_edges(system::System; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(system, AbstractEdge) : get_macro_objs(system, AbstractEdge)
get_storage(system::System; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(system, Storage) : get_macro_objs(system, Storage)
get_transformations(system::System; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(system, Transformation) : get_macro_objs(system, Transformation)

# Function to extract the edges with capacity variables from a system.
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.  
function edges_with_capacity_variables(system::System; return_ids_map::Bool=false)
    if return_ids_map
        edges, edge_asset_map = get_edges(system, return_ids_map=true)
        edges_with_capacity = edges_with_capacity_variables(edges)
        edges_with_capacity_asset_map = filter(edge -> edge[1] in id.(edges_with_capacity), edge_asset_map)
        return edges_with_capacity, edges_with_capacity_asset_map
    else
        return edges_with_capacity_variables(system.assets)
    end
end