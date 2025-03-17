struct NaturalGasDAC <: AbstractAsset
    id::AssetId
    natgasdac_transform::Transformation
    co2_edge::Edge{CO2}
    co2_emission_edge::Edge{CO2}
    ng_edge::Edge{NaturalGas}
    elec_edge::Edge{Electricity}
    co2_captured_edge::Edge{CO2Captured}
end

function default_data(::Type{NaturalGasDAC}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "NaturalGas",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true
                ),
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
            ),
            :ng_edge => @edge_data(
                :commodity => "NaturalGas",
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
            ),
        ),
    )
end

"""
    make(::Type{NaturalGasDAC}, data::AbstractDict{Symbol, Any}, system::System) -> NaturalGasDAC
"""
function make(::Type{NaturalGasDAC}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(NaturalGasDAC, id), data)

    natgasdac_key = :transforms
    @process_data(
        transform_data, 
        data[natgasdac_key], 
        [
            (data, key),
            (data, Symbol("transform_", key)),
            (data[natgasdac_key], key),
            (data[natgasdac_key], Symbol("transform_", key)),
        ]
    )
    natgasdac_transform = Transformation(;
        id = Symbol(id, "_", natgasdac_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    co2_edge_key = :co2_edge
    @process_data(
        co2_edge_data,
        data[:edges][co2_edge_key],
        [
            (data, key),
            (data, Symbol("co2_", key)),
            (data[:edges][co2_edge_key], key),
            (data[:edges][co2_edge_key], Symbol("co2_", key)),
        ]
    )
    @start_vertex(
        co2_start_node,
        co2_edge_data,
        CO2,
        [(data, :co2_sink), (co2_edge_data, :start_vertex)],
    )
    co2_end_node = natgasdac_transform
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

    co2_emission_edge_key = :co2_emission_edge
    @process_data(
        co2_emission_edge_data,
        data[:edges][co2_emission_edge_key],
        [
            (data, Symbol("co2_emission_", key)),
            (data[:edges][co2_emission_edge_key], key),
            (data[:edges][co2_emission_edge_key], Symbol("co2_emission_", key)),
        ]
    )
    co2_emission_start_node = natgasdac_transform
    @end_vertex(
        co2_emission_end_node,
        co2_emission_edge_data,
        CO2,
        [(data, :co2_sink), (co2_emission_edge_data, :end_vertex)],
    )
    co2_emission_edge = Edge(
        Symbol(id, "_", co2_emission_edge_key),
        co2_emission_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_emission_start_node,
        co2_emission_end_node,
    )
    co2_emission_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_emission_edge.unidirectional = true;
    co2_emission_edge.has_capacity = false;

    ng_edge_key = :ng_edge
    @process_data(
        ng_edge_data, 
        data[:edges][ng_edge_key], 
        [
            (data, Symbol("ng_", key)),
            (data[:edges][ng_edge_key], key),
            (data[:edges][ng_edge_key], Symbol("ng_", key)),
        ]
    )
    @start_vertex(
        ng_start_node,
        ng_edge_data,
        NaturalGas,
        [(data, :location), (ng_edge_data, :start_vertex)],
    )
    ng_end_node = natgasdac_transform
    ng_edge = Edge(
        Symbol(id, "_", ng_edge_key),
        ng_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        ng_start_node,
        ng_end_node,
    )
    ng_edge.constraints = get(ng_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    ng_edge.unidirectional = true;
    ng_edge.has_capacity = false;

    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data, 
        data[:edges][elec_edge_key], 
        [
            (data, Symbol("elec_", key)),
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
        ]
    )
    elec_start_node = natgasdac_transform
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
    elec_edge.constraints = Vector{AbstractTypeConstraint}()
    elec_edge.unidirectional = true;
    elec_edge.has_capacity = false;

    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data,
        data[:edges][co2_captured_edge_key],
        [
            (data, Symbol("co2_captured_", key)),
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
        ]
    )
    co2_captured_start_node = natgasdac_transform
    @end_vertex(
        co2_captured_end_node,
        co2_captured_edge_data,
        CO2Captured,
        [(data, :co2_captured_sink), (co2_captured_edge_data, :end_vertex)],
    )
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_captured_edge.unidirectional = true;
    co2_captured_edge.has_capacity = false;

    natgasdac_transform.balance_data = Dict(
        :elec_production => Dict(
            elec_edge.id => 1.0,
            co2_edge.id => get(transform_data, :electricity_production, 0.0)
        ),
        :fuel_consumption => Dict(
            ng_edge.id => -1.0,
            co2_edge.id => get(transform_data, :fuel_consumption, 0.0)
        ),
        :emissions => Dict(
            ng_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture =>Dict(
            ng_edge.id => get(transform_data, :capture_rate, 1.0),
            co2_edge.id => 1.0,
            co2_captured_edge.id => 1.0
        )
    )

    return NaturalGasDAC(id, natgasdac_transform, co2_edge,co2_emission_edge, ng_edge, elec_edge, co2_captured_edge) 
end
