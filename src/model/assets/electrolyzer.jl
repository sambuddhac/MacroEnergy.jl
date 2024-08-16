struct Electrolyzer <: AbstractAsset
    electrolyzer_transform::Transformation
    h2_edge::Edge{Hydrogen}
    e_edge::Edge{Electricity}
end

id(b::Electrolyzer) = b.electrolyzer_transform.id

"""
    make(::Type{Electrolyzer}, data::AbstractDict{Symbol, Any}, system::System) -> Electrolyzer

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - time_commodity: String
        - efficiency_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - h2: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - elec: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{Electrolyzer}, data::AbstractDict{Symbol, Any}, system::System)
    transform_data = validate_data(data[:transforms])

    electrolyzer = Transformation(;
    id = Symbol(transform_data[:id]),
    timedata = deepcopy(system.time_data[Symbol(transform_data[:time_commodity])]),
    constraints = get(transform_data, :constraints, [BalanceConstraint()])
    )

    elec_edge_data = validate_data(data[:edges][:elec])
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = electrolyzer
    elec_edge = Edge(Symbol(elec_edge_data[:id]),elec_edge_data, system.time_data[:Electricity],Electricity, elec_start_node,  elec_end_node)
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true);

    h2_edge_data = validate_data(data[:edges][:h2])
    h2_start_node = electrolyzer
    h2_end_node = find_node(system.locations, Symbol(h2_edge_data[:end_vertex]))
    h2_edge = Edge(Symbol(h2_edge_data[:id]),h2_edge_data, system.time_data[:Hydrogen],Hydrogen, h2_start_node,  h2_end_node );
    h2_edge.constraints = get(h2_edge_data, :constraints, [CapacityConstraint()])
    h2_edge.unidirectional = get(h2_edge_data, :unidirectional, true);

    electrolyzer.balance_data =  Dict(:energy=>Dict(h2_edge.id=>1.0,
                                                    elec_edge.id=>get(transform_data,:efficiency_rate,1.0)))
                                                        
                                                        
    return Electrolyzer(electrolyzer, h2_edge, elec_edge)
end