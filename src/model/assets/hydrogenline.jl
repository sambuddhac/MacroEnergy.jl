struct HydrogenLine <: AbstractAsset
    id::AssetId
    h2_edge::Edge{Hydrogen}
end

function default_data(::Type{HydrogenLine}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :edges => Dict{Symbol,Any}(
            :h2_edge => @edge_data(
                :commodity => "Hydrogen",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => false,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
        ),
    )
end

"""
    make(::Type{HydrogenLine}, data::AbstractDict{Symbol, Any}, system::System) -> HydrogenLine

    Necessary data fields:
     - edges: Dict{Symbol, Any}
         - h2_edge: Dict{Symbol, Any}
             - id: String
             - start_vertex: String
             - end_vertex: String
             - unidirectional: Bool
             - has_capacity: Bool
             - can_retire: Bool
             - can_expand: Bool
             - constraints: Vector{AbstractTypeConstraint}
"""

function make(::Type{<:HydrogenLine}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id]) 

    data = recursive_merge(default_data(HydrogenLine, id), data)

    h2_edge_key = :h2_edge
    @process_data(
        h2_edge_data,
        data[:edges][h2_edge_key],
        [
            (data[:edges][h2_edge_key], key),
            (data[:edges][h2_edge_key], Symbol("h2_", key)),
            (data, Symbol("h2_", key)),
            (data, key), 
        ]
    )
    @start_vertex(
        h2_start_node,
        h2_edge_data,
        Hydrogen,
        [(h2_edge_data, :start_vertex), (data, :location)]
    )
    @end_vertex(
        h2_end_node,
        h2_edge_data,
        Hydrogen,
        [(h2_edge_data, :end_vertex), (data, :location)]
    )
    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )
    h2_edge.constraints = get(h2_edge_data, :constraints, [CapacityConstraint()])

    h2_edge.loss_fraction = get(h2_edge_data,:line_loss_percentage,0.0)

    return HydrogenLine(id, h2_edge)
end
