struct BECCSElectricity <: AbstractAsset
    id::AssetId
    beccs_transform::Transformation
    biomass_edge::Edge{<:Biomass}
    elec_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
    co2_emission_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end

function default_data(::Type{BECCSElectricity}, id=missing,)
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Biomass",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :electricity_production => 0.0,
            :co2_content => 0.0,
            :emission_rate => 1.0,
            :capture_rate => 1.0
        ),
        :edges => Dict{Symbol,Any}(
            :biomass_edge => @edge_data(
                :commodity => "Biomass",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
            ),
            :co2_edge => @edge_data(
                :commodity => "CO2",
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
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

function make(::Type{BECCSElectricity}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(BECCSElectricity, id), data)

    beccs_transform_key = :transforms
    @process_data(transform_data, data[beccs_transform_key], [
        (data, key),
        (data, Symbol("transform_", key)),
        (data[beccs_transform_key], key),
        (data[beccs_transform_key], Symbol("transform_", key))
    ])
    beccs_transform = Transformation(;
        id = Symbol(id, "_", beccs_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    biomass_edge_key = :biomass_edge
    @process_data(biomass_edge_data, data[:edges][biomass_edge_key], [
        (data, key),
        (data, Symbol("biomass_", key)),
        (data[:edges][biomass_edge_key], key),
        (data[:edges][biomass_edge_key], Symbol("biomass_", key))
    ])
    commodity_symbol = Symbol(biomass_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        biomass_start_node,
        biomass_edge_data,
        commodity,
        [(data, :location), (biomass_edge_data, :start_vertex)],
    )
    biomass_end_node = beccs_transform
    biomass_edge = Edge(
        Symbol(id, "_", biomass_edge_key),
        biomass_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        biomass_start_node,
        biomass_end_node,
    )
    biomass_edge.constraints = get(biomass_edge_data, :constraints, [CapacityConstraint()])
    biomass_edge.unidirectional = get(biomass_edge_data, :unidirectional, true)

    co2_edge_key = :co2_edge
    @process_data(co2_edge_data, data[:edges][co2_edge_key], [
        (data, Symbol("co2_", key)),
        (data[:edges][co2_edge_key], key),
        (data[:edges][co2_edge_key], Symbol("co2_", key))
    ])
    @start_vertex(
        co2_start_node,
        co2_edge_data,
        CO2,
        [(data, :co2_sink), (co2_edge_data, :start_vertex)],
    )
    co2_end_node = beccs_transform
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    co2_edge.constraints = get(co2_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_edge.unidirectional = get(co2_edge_data, :unidirectional, true)
    co2_edge.has_capacity = get(co2_edge_data, :has_capacity, false)

    co2_emission_edge_key = :co2_emission_edge
    @process_data(co2_emission_edge_data, data[:edges][co2_emission_edge_key], [
        (data, Symbol("co2_emission_", key)),
        (data[:edges][co2_emission_edge_key], key),
        (data[:edges][co2_emission_edge_key], Symbol("co2_emission_", key))
    ])
    co2_emission_start_node = beccs_transform
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
    co2_emission_edge.constraints = get(co2_emission_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_emission_edge.unidirectional = get(co2_emission_edge_data, :unidirectional, true)
    co2_emission_edge.has_capacity = get(co2_emission_edge_data, :has_capacity, false)

    elec_edge_key = :elec_edge
    @process_data(elec_edge_data, data[:edges][elec_edge_key], [
        (data, Symbol("elec_", key)),
        (data[:edges][elec_edge_key], key),
        (data[:edges][elec_edge_key], Symbol("elec_", key))
    ])
    elec_start_node = beccs_transform
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
    elec_edge.constraints = get(elec_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)
    elec_edge.has_capacity = get(elec_edge_data, :has_capacity, false)

    co2_captured_edge_key = :co2_captured_edge
    @process_data(co2_captured_edge_data, data[:edges][co2_captured_edge_key], [
        (data, Symbol("co2_captured_", key)),
        (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
        (data[:edges][co2_captured_edge_key], key)
    ])
    co2_captured_start_node = beccs_transform
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
    co2_captured_edge.constraints = get(co2_captured_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_captured_edge.unidirectional = get(co2_captured_edge_data, :unidirectional, true)
    co2_captured_edge.has_capacity = get(co2_captured_edge_data, :has_capacity, false)

    beccs_transform.balance_data = Dict(
        :elec_production => Dict(
            elec_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :electricity_production, 0.0)
        ),
        :negative_emissions => Dict(
            biomass_edge.id => get(transform_data, :co2_content, 0.0),
            co2_edge.id => -1.0
        ),
        :emissions => Dict(
            biomass_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture =>Dict(
            biomass_edge.id => get(transform_data, :capture_rate, 1.0),
            co2_captured_edge.id => 1.0
        )
    )

    return BECCSElectricity(id, beccs_transform, biomass_edge,elec_edge,co2_edge,co2_emission_edge,co2_captured_edge) 
end
