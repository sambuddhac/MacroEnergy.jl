struct PowerLine <: AbstractAsset
    id::AssetId
    elec_edge::Edge{Electricity}
end

function default_data(::Type{PowerLine}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :edges => Dict{Symbol,Any}(
            :elec_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
        ),
    )
end

"""
    make(::Type{PowerLine}, data::AbstractDict{Symbol, Any}, system::System) -> PowerLine
"""

function make(::Type{<:PowerLine}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id]) 

    data = recursive_merge(default_data(PowerLine, id), data)

    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data,
        data[:edges][elec_edge_key],
        [
            (data, key), 
            (data, Symbol("elec_", key)),
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
        ]
    )
    @start_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(data, :location), (elec_edge_data, :start_vertex)],
    )
    @end_vertex(
        elec_end_node,
        elec_edge_data,
        Electricity,
        [(data, :location), (elec_edge_data, :end_vertex)],
    )
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = get(elec_edge_data, :constraints, [CapacityConstraint()])

    elec_edge.loss_fraction = get(elec_edge_data,:line_loss_percentage,0.0)

    return PowerLine(id, elec_edge)
end
