struct VRE <: AbstractAsset
    id::AssetId
    energy_transform::Transformation
    edge::Edge{Electricity}
end

function default_data(::Type{VRE}, id=missing)
    return Dict{Symbol, Any}(
        :id => id,
        :transforms => Dict{Symbol, Any}(
            :timedata => "Electricity",
            :constraints => Dict{Symbol,Bool}()
        ),
        :edges => Dict{Symbol, Any}(
            :edge => Dict{Symbol, Any}(
                :end_vertex => missing,
                :type => "Electricity",
                :unidirectional => true,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :has_capacity => true,
                :can_expand => true,
                :can_retire => false,
                :capacity_size => 1.0,
                :existing_capacity => 0.0,
                :min_capacity => 0.0,
                :max_capacity => Inf,
                :availability => 1.0,
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
    loaded_elec_edge_data = Dict{Symbol,Any}(
        key => get_from([
                (data, key),
                (data, Symbol("edge_", key)),
                (data[:edges][elec_edge_key], key),
                (data[:edges][elec_edge_key], Symbol("edge_", key))],
            missing)
        for key in keys(data[:edges][elec_edge_key])
    )
    remove_missing!(loaded_elec_edge_data)
    recursive_merge!(data[:edges][elec_edge_key][:constraints], loaded_elec_edge_data[:constraints])
    merge!(data[:edges][elec_edge_key], loaded_elec_edge_data)
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = vre_transform
    end_vertex = get_from([(data, :location), (elec_edge_data, :end_vertex)], missing)
    elec_edge_data[:end_vertex] = end_vertex
    elec_end_node = find_node(system.locations, Symbol(end_vertex), Electricity)
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
