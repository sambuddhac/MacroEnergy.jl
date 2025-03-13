struct BECCSHydrogen <: AbstractAsset
    id::AssetId
    beccs_transform::Transformation
    biomass_edge::Edge{<:Biomass}
    h2_edge::Edge{Hydrogen}
    elec_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
    co2_emission_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end

function default_data(::Type{BECCSHydrogen}, id=missing,)
    return Dict{Symbol, Any}(
        :id => id,
        :transforms => Dict{Symbol, Any}(
            :timedata => "Biomass",
            :hydrogen_production =>  0.0,
            :electricity_consumption =>  0.0,
            :capture_rate =>  0.0,
            :co2_content => 0.0,
            :emission_rate => 0.0,
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
        ),
        :edges => Dict{Symbol, Any}(
            :elec_edge => Dict{Symbol, Any}(
                :type => "Electricity",
                :start_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :can_expand => false,
                :can_retire => false,
                :constraints => Dict{Symbol,Bool}()
            ),
            :h2_edge => Dict{Symbol, Any}(
                :type => "Hydrogen",
                :start_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :can_expand => false,
                :can_retire => false,
                :constraints => Dict{Symbol,Bool}()
            ),
            :biomass_edge => Dict{Symbol, Any}(
                :type => "Biomass",
                :start_vertex => missing,
                :unidirectional => true,
                :integer_decisions => false,
                :has_capacity => true,
                :existing_capacity => 0.0,
                :capacity_size => 1.0,
                :can_expand => true,
                :can_retire => true,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :availability => 1.0,
                :min_flow_fraction => 0.0,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
            ),
            :co2_edge => Dict{Symbol, Any}(
                :type => "CO2",
                :start_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :can_expand => false,
                :can_retire => false,
                :constraints => Dict{Symbol,Bool}()
            ),
            :co2_emission_edge => Dict{Symbol, Any}(
                :type => "CO2",
                :end_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :can_expand => false,
                :can_retire => false,
                :constraints => Dict{Symbol,Bool}()
            ),
            :co2_captured_edge => Dict{Symbol, Any}(
                :type => "CO2Captured",
                :end_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :can_expand => false,
                :can_retire => false,
                :constraints => Dict{Symbol,Bool}()
            )
        )
    )
end

function make(::Type{BECCSHydrogen}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(BECCSHydrogen, id), data)

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
    commodity_symbol = Symbol(biomass_edge_data[:type])
    start_vertex = get_from([(data, :location), (biomass_edge_data, :start_vertex)], missing)
    biomass_edge_data[:start_vertex] = start_vertex
    biomass_start_node = find_node(system.locations, Symbol(start_vertex), commodity_types()[commodity_symbol])
    biomass_end_node = beccs_transform
    biomass_edge = Edge(
        Symbol(id, "_", biomass_edge_key),
        biomass_edge_data,
        system.time_data[commodity_symbol],
        commodity_types()[commodity_symbol],
        biomass_start_node,
        biomass_end_node,
    )
    biomass_edge.constraints = get(biomass_edge_data, :constraints, [CapacityConstraint()])
    biomass_edge.unidirectional = get(biomass_edge_data, :unidirectional, true)

    h2_edge_key = :h2_edge
    @process_data(h2_edge_data, data[:edges][h2_edge_key], [
        (data, Symbol("h2_", key)),
        (data[:edges][h2_edge_key], key),
        (data[:edges][h2_edge_key], Symbol("h2_", key))
    ])
    h2_start_node = beccs_transform
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
    h2_edge.constraints = get(h2_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    h2_edge.unidirectional = get(h2_edge_data, :unidirectional, true)
    h2_edge.has_capacity = get(h2_edge_data, :has_capacity, false)

    co2_edge_key = :co2_edge
    @process_data(co2_edge_data, data[:edges][co2_edge_key], [
        (data, Symbol("co2_", key)),
        (data[:edges][co2_edge_key], key),
        (data[:edges][co2_edge_key], Symbol("co2_", key))
    ])
    start_vertex = get_from([(data, :co2_sink), (co2_edge_data, :start_vertex)], missing)
    co2_edge_data[:start_vertex] = start_vertex
    co2_start_node = find_node(system.locations, Symbol(start_vertex), CO2)
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
    end_vertex = get_from([(data, :co2_sink), (co2_emission_edge_data, :end_vertex)], missing)
    co2_emission_edge_data[:end_vertex] = end_vertex
    co2_emission_end_node = find_node(system.locations, Symbol(end_vertex), CO2)
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
    elec_end_node = beccs_transform
    start_vertex = get_from([(data, :location), (elec_edge_data, :start_vertex)], missing)
    elec_edge_data[:start_vertex] = start_vertex
    elec_start_node = find_node(system.locations, Symbol(start_vertex), Electricity)
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
    co2_captured_edge.has_capacity = get(co2_captured_edge_data, :has_capacity, false)

    beccs_transform.balance_data = Dict(
        :h2_production => Dict(
            h2_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :hydrogen_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_edge.id => -1.0,
            biomass_edge.id => get(transform_data, :electricity_consumption, 0.0)
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

    return BECCSHydrogen(id, beccs_transform, biomass_edge,h2_edge,elec_edge,co2_edge,co2_emission_edge,co2_captured_edge) 
end
