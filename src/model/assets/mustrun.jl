struct MustRun <: AbstractAsset
    id::AssetId
    energy_transform::Transformation
    elec_edge::Edge{Electricity}
end

function default_data(::Type{MustRun}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
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
    make(::Type{MustRun}, data::AbstractDict{Symbol, Any}, system::System) -> MustRun
"""
function make(asset_type::Type{MustRun}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(MustRun, id), data)

    energy_key = :transforms
    @process_data(
        transform_data, 
        data[energy_key], 
        [
            (data, key),
            (data, Symbol("transform_", key)),
            (data[energy_key], key),
            (data[energy_key], Symbol("transform_", key)),
        ]
    )
    mustrun_transform = Transformation(;
        id = Symbol(id, "_", energy_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
    )

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
    elec_start_node = mustrun_transform
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
    elec_edge.constraints = get(elec_edge_data, :constraints, [MustRunConstraint()])
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)

    return asset_type(id, mustrun_transform, elec_edge)
end