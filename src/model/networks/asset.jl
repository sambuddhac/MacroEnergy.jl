id(asset::AbstractAsset) = asset.id

"""
    struct_info(t::Type{T}) where T

    Return a vector of tuples with the field names and types of a struct.
"""
function struct_info(::Type{T}, include_id::Bool=false) where T
    if include_id
        names = Base.fieldnames(T)
    else
        names = fieldnames(T)
    end
    return [(names[idx], x) for (idx, x) in enumerate(T.types)]
end

function struct_info(asset::T) where T
    return struct_info(typeof(asset))
end

function print_struct_info(asset::AbstractAsset)
    info = struct_info(typeof(asset))
    print_struct_info(info) 
end

function print_struct_info(asset::Type{<:AbstractAsset})
    info = struct_info(asset)
    print_struct_info(info) 
end

function print_struct_info(info::Vector{Tuple{Symbol, DataType}})
    for (name, type) in info
        println("Field: $name, Type: $type")
    end    
end

# The following functions are used to extract all the edges from an Asset or a Vector of Assets
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.
get_edges(asset::AbstractAsset; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(asset, AbstractEdge) : get_macro_objs(asset, AbstractEdge)
get_edges(assets::Vector{<:AbstractAsset}; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(assets, AbstractEdge) : get_macro_objs(assets, AbstractEdge)

# The following functions are used to extract the edges with capacity variables from a Vector of Assets or a single Asset.
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.  
function edges_with_capacity_variables(assets::Vector{<:AbstractAsset}; return_ids_map::Bool=false)
    if return_ids_map
        all_edges = Vector{Vector{AbstractEdge}}(undef, length(assets))
        all_edge_asset_map = Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
        for i in eachindex(assets)
            asset = assets[i]
            edges, edge_asset_map = edges_with_capacity_variables(asset, return_ids_map=true)
            all_edges[i] = edges
            merge!(all_edge_asset_map, edge_asset_map)
        end
        return reduce(vcat, all_edges), all_edge_asset_map
    else
        return reduce(vcat, [edges_with_capacity_variables(asset) for asset in assets])
    end
end
function edges_with_capacity_variables(asset::AbstractAsset; return_ids_map::Bool=false)
    if return_ids_map
        edges, edge_asset_map = get_edges(asset, return_ids_map=true)
        edges_with_capacity = edges_with_capacity_variables(edges)
        edges_with_capacity_asset_map = filter(edge -> edge[1] in id.(edges_with_capacity), edge_asset_map)
        return edges_with_capacity, edges_with_capacity_asset_map
    else
        return AbstractEdge[edge for edge in get_edges(asset) if has_capacity(edge)]
    end
end
