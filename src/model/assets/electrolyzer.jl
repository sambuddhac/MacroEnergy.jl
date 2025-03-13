struct Electrolyzer <: AbstractAsset
    id::AssetId
    electrolyzer_transform::Transformation
    h2_edge::Edge{Hydrogen}
    elec_edge::Edge{Electricity}
end

function default_data(::Type{Electrolyzer}, id=missing)
    return Dict(
        :id => id,
        :transforms => Dict(
            :timedata => "Electricity",
            :efficiency_rate => 1.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :efficiency_rate => 0.0
        ),
        :edges => Dict(
            :h2_edge => Dict(
                :commodity => "Hydrogen",
                :end_vertex => missing,
                :unidirectional => true,
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :existing_capacity => 0.0,
                :capacity_size => 1.0,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :ramp_up_fraction => 1.0,
                :ramp_down_fraction => 1.0,
                :min_flow_fraction => 0.0,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :elec_edge => Dict(
                :commodity => "Electricity",
                :start_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :can_retire => false,
                :can_expand => false,
                :constraints => Dict{Symbol, Bool}()
            ),
        ),
    )
end

"""
    make(::Type{Electrolyzer}, data::AbstractDict{Symbol, Any}, system::System) -> Electrolyzer

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
        - efficiency_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - h2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - e_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{Electrolyzer}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(Electrolyzer, id), data)

    electrolyzer_key = :transforms
    @process_data(transform_data, data[electrolyzer_key], [
        (data, key),
        (data, Symbol("transform_", key)),
        (data[electrolyzer_key], key),
        (data[electrolyzer_key], Symbol("transform_", key))
        ])
    electrolyzer = Transformation(;
        id = Symbol(id, "_", electrolyzer_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :elec_edge
    @process_data(elec_edge_data, data[:edges][elec_edge_key], [
                    (data, Symbol("elec_", key)),
                    (data[:edges][elec_edge_key], key),
                    (data[:edges][elec_edge_key], Symbol("elec_", key))
    ])
    start_vertex = get_from([(data, :location), (elec_edge_data, :start_vertex)], missing)
    elec_edge_data[:start_vertex] = start_vertex
    elec_start_node = find_node(system.locations, Symbol(start_vertex), Electricity)
    elec_end_node = electrolyzer
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)

    h2_edge_key = :h2_edge
    @process_data(h2_edge_data, data[:edges][h2_edge_key], [
                    (data, key),
                    (data, Symbol("h2_", key)),
                    (data[:edges][h2_edge_key], key),
                    (data[:edges][h2_edge_key], Symbol("h2_", key))
    ])
    h2_start_node = electrolyzer
    end_vertex = get_from([(data, :location), (h2_edge_data, :end_vertex)], missing)
    h2_edge_data[:end_vertex] = end_vertex
    h2_end_node = find_node(system.locations, Symbol(end_vertex), Hydrogen)
    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )
    h2_edge.constraints = get(h2_edge_data, :constraints, [CapacityConstraint()])
    h2_edge.unidirectional = get(h2_edge_data, :unidirectional, true)

    electrolyzer.balance_data = Dict(
        :energy => Dict(
            h2_edge.id => 1.0,
            elec_edge.id => get(transform_data, :efficiency_rate, 1.0),
        ),
    )

    return Electrolyzer(id, electrolyzer, h2_edge, elec_edge)
end
