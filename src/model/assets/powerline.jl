struct PowerLine <: AbstractAsset
    elec_edge::Edge{Electricity}
end
id(b::PowerLine) = b.elec_edge.id

function make(asset_type::Type{<:PowerLine}, data::AbstractDict{Symbol, Any}, system::System)

    elec_edge_data = validate_data(data[:edges][:line])

    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))

    
    elec_edge = Edge(Symbol("E_"*elec_edge_data[:id]),elec_edge_data, system.time_data[:Electricity],Electricity, elec_start_node,  elec_end_node);
    elec_edge.constraints = get(elec_edge_data, :constraints, [CapacityConstraint()])


    return asset_type(elec_edge)
end
