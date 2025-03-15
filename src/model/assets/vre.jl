struct VRE <: AbstractAsset
    id::AssetId
    energy_transform::Transformation
    edge::Edge{Electricity}
end

function default_data(::Type{VRE}, id=missing)
    return Dict{Symbol, Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
        ),
        :edges => Dict{Symbol, Any}(
            :edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
            ),
        ),
    )
end

"""
    make(::Type{<:VRE}, data::AbstractDict{Symbol, Any}, system::System) -> VRE
    
    VRE is an alias for Union{SolarPV, WindTurbine}

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
    - edges: Dict{Symbol, Any}
        - edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(asset_type::Type{<:VRE}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(VRE, id), data)

    energy_key = :transforms
    loaded_transform_data = Dict{Symbol,Any}(
        key => get_from([
                (data, Symbol("transform_", key)),
                (data[energy_key], Symbol("transform_", key)),
                (data[energy_key], key)],
            missing)
        for key in keys(data[energy_key])
    )
    remove_missing!(loaded_transform_data)
    recursive_merge!(data[energy_key][:constraints], loaded_transform_data[:constraints])
    merge!(data[energy_key], loaded_transform_data)
    transform_data = process_data(data[energy_key])
    vre_transform = Transformation(;
        id = Symbol(id, "_", energy_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
    )

    elec_edge_key = :edge
    @process_data(
        elec_edge_data,
        data[:edges][elec_edge_key],
        [
            (data, key),
            (data, Symbol("elec_", key)),
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
        ],
    )
    elec_start_node = vre_transform
    @end_vertex(
        elec_end_node,
        elec_edge_data,
        Electricity,
        [(data, :location), (elec_edge_data, :end_vertex)]
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
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)

    return asset_type(id, vre_transform, elec_edge)
end
