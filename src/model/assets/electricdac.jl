struct ElectricDAC <: AbstractAsset
    id::AssetId
    electricdac_transform::Transformation
    co2_edge::Edge{CO2}
    elec_edge::Edge{Electricity}
    co2_captured_edge::Edge{CO2Captured}
end

function default_data(::Type{ElectricDAC}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => Dict{Symbol,Any}(
            :timedata => "Electricity",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
            ),
            :electricity_consumption => 0.0,
        ),
        :edges => Dict{Symbol,Any}(
            :co2_edge => Dict{Symbol,Any}(
                :type => "CO2",
                :start_vertex => missing,
                :timedata => "CO2",
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                ),
                :unidirectional => true,
                :has_capacity => true,
                :existing_capacity => 0.0,
                :capacity_size => 1.0,
                :can_expand => true,
                :can_retire => true,
                :uc => false,
                :integer_decisions => false,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :ramp_up_fraction => 1.0,
                :ramp_down_fraction => 1.0,
            ),
            :elec_edge => Dict{Symbol,Any}(
                :type => "Electricity",
                :start_vertex => missing,
                :timedata => "Electricity",
                :constraints => Dict{Symbol,Bool}(),
                :unidirectional => true,
                :has_capacity => false,
            ),
            :co2_captured_edge => Dict{Symbol,Any}(
                :type => "CO2Captured",
                :end_vertex => missing,
                :timedata => "CO2Captured",
                :constraints => Dict{Symbol,Bool}(),
                :unidirectional => true,
                :has_capacity => false,
            ),
        ),
    )
end

function make(::Type{ElectricDAC}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(ElectricDAC, id), data)

    electricdac_key = :transforms
    @process_data(transform_data, data[electricdac_key], [
        (data, key),
        (data, Symbol("transform_", key)),
        (data[electricdac_key], key),
        (data[electricdac_key], Symbol("transform_", key))
    ])
    electricdac_transform = Transformation(;
        id = Symbol(id, "_", electricdac_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )
    
    co2_edge_key = :co2_edge
    @process_data(co2_edge_data, data[:edges][co2_edge_key], [
        (data, key),
        (data, Symbol("co2_", key)),
        (data[:edges][co2_edge_key], key),
        (data[:edges][co2_edge_key], Symbol("co2_", key))
    ])
    start_vertex = get_from([(data, :co2_sink), (co2_edge_data, :start_vertex)], missing)
    co2_edge_data[:start_vertex] = start_vertex
    co2_start_node = find_node(system.locations, Symbol(start_vertex), CO2)
    co2_end_node = electricdac_transform
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    co2_edge.constraints = get(co2_edge_data, :constraints, [CapacityConstraint()])
    co2_edge.unidirectional = get(co2_edge_data, :unidirectional, true)

    elec_edge_key = :elec_edge
    @process_data(elec_edge_data, data[:edges][elec_edge_key], [
        (data, Symbol("elec_", key)),
        (data[:edges][elec_edge_key], key),
        (data[:edges][elec_edge_key], Symbol("elec_", key))
    ])
    start_vertex = get_from([(data, :location), (elec_edge_data, :start_vertex)], missing)
    elec_edge_data[:start_vertex] = start_vertex
    elec_start_node = find_node(system.locations, Symbol(start_vertex), Electricity)
    elec_end_node = electricdac_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = get(elec_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)

    co2_captured_edge_key = :co2_captured_edge
    @process_data(co2_captured_edge_data, data[:edges][co2_captured_edge_key], [
        (data, Symbol("co2_captured_", key)),
        (data[:edges][co2_captured_edge_key], key),
        (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key))
    ])
    co2_captured_start_node = electricdac_transform
    end_vertex = get_from([(data, :co2_captured_sink), (co2_captured_edge_data, :end_vertex)], missing)
    co2_captured_edge_data[:end_vertex] = end_vertex
    co2_captured_end_node = find_node(system.locations, Symbol(end_vertex), CO2Captured)
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.constraints = get(co2_captured_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_captured_edge.unidirectional = get(co2_captured_edge_data, :unidirectional, true)

    electricdac_transform.balance_data = Dict(
        :energy => Dict(
            co2_captured_edge.id => get(transform_data, :electricity_consumption, 0.0),
            elec_edge.id => 1.0,
        ),
        :capture => Dict(
            co2_edge.id => 1.0,
            co2_captured_edge.id => 1.0,
        ),
    )

    return ElectricDAC(id, electricdac_transform, co2_edge, elec_edge, co2_captured_edge)
end
