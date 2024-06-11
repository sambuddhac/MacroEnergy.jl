function create_system(nodes::Dict{Symbol,Node}, assets::Dict{Symbol,AbstractAsset})
    system = Vector{Union{Node, AbstractAsset}}()
    for (_, node) in nodes
        push!(system, node)
    end
    for (_, asset) in assets
        push!(system, asset)
    end
    return system
end