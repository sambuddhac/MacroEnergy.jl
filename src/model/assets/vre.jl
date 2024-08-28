struct SolarPV <: AbstractAsset
    energy_transform::Transformation
    edge::Edge{Electricity}
end

struct WindTurbine <: AbstractAsset
    energy_transform::Transformation
    edge::Edge{Electricity}
end


const VRE = Union{
    SolarPV, WindTurbine
}

id(g::VRE) = g.energy_transform.id


"""
    make(::Type{<:VRE}, data::AbstractDict{Symbol, Any}, system::System) -> VRE
    
    VRE is an alias for Union{SolarPV, WindTurbine}

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - time_commodity: String
    - edges: Dict{Symbol, Any}
        - id: String
        - end_vertex: String
        - unidirectional: Bool
        - has_planning_variables: Bool
        - can_retire: Bool
        - can_expand: Bool
        - constraints: Vector{AbstractTypeConstraint}
"""
function make(asset_type::Type{<:VRE}, data::AbstractDict{Symbol, Any}, system::System)
    transform_data = validate_data(data[:transforms])
    vre_transform = Transformation(;
        id = Symbol(transform_data[:id]),
        timedata = system.time_data[Symbol(transform_data[:time_commodity])],
    )

    elec_edge_data = validate_data(data[:edges])
    elec_start_node = vre_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))

    elec_edge = Edge(Symbol(elec_edge_data[:id]),elec_edge_data, system.time_data[:Electricity],Electricity, elec_start_node,  elec_end_node );
    elec_edge.constraints = get(elec_edge_data, :constraints, [CapacityConstraint()])
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true);

    return asset_type(vre_transform, elec_edge)
end