struct BECCSElectricity <: AbstractAsset
    id::AssetId
    beccs_transform::Transformation
    biomass_edge::Edge{Biomass}
    elec_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
    co2_emission_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end

function default_data(::Type{BECCSElectricity}, id=missing,)
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => Dict{Symbol,Any}(
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
            :biomass_edge => Dict{Symbol,Any}(
                :type => "Biomass",
                :start_vertex => missing,
                :unidirectional => true,
                :has_capacity => true,
                :existing_capacity => 0.0,
                :can_expand => true,
                :can_retire => true,
                :efficiency => 1.0,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                    :MinFlowConstraint => true
                )
            ),
            :co2_edge => Dict{Symbol,Any}(
                :type => "CO2",
                :start_vertex => missing,
                :unidirectional => true,
                :has_capacity => true,
                :existing_capacity => 0.0,
                :can_expand => true,
                :can_retire => false,
                :efficiency => 1.0,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol,Bool}()
            ),
            :co2_emission_edge => Dict{Symbol,Any}(
                :type => "CO2",
                :end_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :existing_capacity => 0.0,
                :can_expand => true,
                :can_retire => false,
                :efficiency => 1.0,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol,Bool}()
            ),
            :elec_edge => Dict{Symbol,Any}(
                :type => "Electricity",
                :end_vertex => missing,
                :unidirectional => true,
                :has_capacity => true,
                :existing_capacity => 0.0,
                :can_expand => true,
                :can_retire => false,
                :efficiency => 1.0,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol,Bool}()
            ),
            :co2_captured_edge => Dict{Symbol,Any}(
                :type => "CO2Captured",
                :end_vertex => missing,
                :unidirectional => true,
                :has_capacity => true,
                :existing_capacity => 0.0,
                :can_expand => true,
                :can_retire => false,
                :efficiency => 1.0,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol,Bool}()
            ),
        ),
    )
end

function make(::Type{BECCSElectricity}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(BECCSElectricity), data)

    beccs_transform_key = :transforms
    loaded_transform_data = Dict{Symbol, Any}(
        key => get_from([
                (data, key),
                (data, Symbol("transform_", key)),
                (data[beccs_transform_key], key),
                (data[beccs_transform_key], Symbol("transform_", key))],
            missing)
        for key in keys(data[:transforms])
    )
    remove_missing!(loaded_transform_data)
    merge!(data[beccs_transform_key], loaded_transform_data)
    transform_data = process_data(data[beccs_transform_key])
    beccs_transform = Transformation(;
        id = Symbol(id, "_", beccs_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    biomass_edge_key = :biomass_edge
    loaded_biomass_data = Dict{Symbol, Any}(
        key => get_from([
                (data, key),
                (data, Symbol("biomass_", key)),
                (data[:edges][biomass_edge_key], Symbol("biomass_", key)),
                (data[:edges][biomass_edge_key], key)],
            missing)
        for key in keys(data[:edges][biomass_edge_key])
    )
    remove_missing!(loaded_biomass_data)
    merge!(data[:edges][biomass_edge_key], loaded_biomass_data)
    biomass_edge_data = process_data(data[:edges][biomass_edge_key])
    start_vertex = get_from([(data, :location), (biomass_edge_data, :start_vertex)], missing)
    biomass_edge_data[:start_vertex] = start_vertex
    biomass_start_node = find_node(system.locations, Symbol(start_vertex), Biomass)
    biomass_end_node = beccs_transform
    biomass_edge = Edge(
        Symbol(id, "_", biomass_edge_key),
        biomass_edge_data,
        system.time_data[:Biomass],
        Biomass,
        biomass_start_node,
        biomass_end_node,
    )
    biomass_edge.constraints = get(biomass_edge_data, :constraints, [CapacityConstraint()])
    biomass_edge.unidirectional = get(biomass_edge_data, :unidirectional, true)

    co2_edge_key = :co2_edge
    loaded_co2_data = Dict{Symbol, Any}(
        key => get_from([
                (data, Symbol("co2_", key)),
                (data[:edges][co2_edge_key], Symbol("co2_", key)),
                (data[:edges][co2_edge_key], key)],
            missing)
        for key in keys(data[:edges][co2_edge_key])
    )
    remove_missing!(loaded_co2_data)
    merge!(data[:edges][co2_edge_key], loaded_co2_data)
    co2_edge_data = process_data(data[:edges][co2_edge_key])
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
    co2_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_edge.unidirectional = true;
    co2_edge.has_capacity = false;

    co2_emission_edge_key = :co2_emission_edge
    loaded_co2_emission_data = Dict{Symbol, Any}(
        key => get_from([
                (data, Symbol("co2_emission_", key)),
                (data[:edges][co2_emission_edge_key], Symbol("co2_emission_", key)),
                (data[:edges][co2_emission_edge_key], key)],
            missing)
        for key in keys(data[:edges][co2_emission_edge_key])
    )
    remove_missing!(loaded_co2_emission_data)
    merge!(data[:edges][co2_emission_edge_key], loaded_co2_emission_data)
    co2_emission_edge_data = process_data(data[:edges][co2_emission_edge_key])
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
    co2_emission_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_emission_edge.unidirectional = true;
    co2_emission_edge.has_capacity = false;

    elec_edge_key = :elec_edge
    loaded_elec_data = Dict{Symbol, Any}(
        key => get_from([
                (data, Symbol("elec_", key)),
                (data[:edges][elec_edge_key], Symbol("elec_", key)),
                (data[:edges][elec_edge_key], key)],
            missing)
        for key in keys(data[:edges][elec_edge_key])
    )
    remove_missing!(loaded_elec_data)
    merge!(data[:edges][elec_edge_key], loaded_elec_data)
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = beccs_transform
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
    elec_edge.constraints = Vector{AbstractTypeConstraint}()
    elec_edge.unidirectional = true;
    elec_edge.has_capacity = false;

    co2_captured_edge_key = :co2_captured_edge
    loaded_co2_captured_data = Dict{Symbol, Any}(
        key => get_from([
                (data, Symbol("co2_captured_", key)),
                (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
                (data[:edges][co2_captured_edge_key], key)],
            missing)
        for key in keys(data[:edges][co2_captured_edge_key])
    )
    remove_missing!(loaded_co2_captured_data)
    merge!(data[:edges][co2_captured_edge_key], loaded_co2_captured_data)
    co2_captured_edge_data = process_data(data[:edges][co2_captured_edge_key])
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
    co2_captured_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_captured_edge.unidirectional = true;
    co2_captured_edge.has_capacity = false;

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
