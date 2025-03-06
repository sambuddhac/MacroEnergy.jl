struct Battery <: AbstractAsset
    id::AssetId
    battery_storage::AbstractStorage{Electricity}
    discharge_edge::Edge{Electricity}
    charge_edge::Edge{Electricity}
end

function default_data(::Type{Battery}, id=missing,)
    return Dict{Symbol,Any}(
        :id => id,
        :storage => Dict{Symbol,Any}(
            :commodity => "Electricity",
            :can_retire => false,
            :can_expand => true,
            :long_duration => false,
            :existing_capacity => 0.0,
            :investment_cost => 0.0,
            :fixed_om_cost => 0.0,
            :loss_fraction => 0.0,
            :min_duration => 0.0,
            :max_duration => 0.0,
            :min_storage_level => 0.0,
            :min_capacity => 0.0,
            :max_capacity => Inf,
            :constraints => Dict{Symbol,Bool}(
                :StorageCapacityConstraint => true,
                :StorageSymmetricCapacityConstraint => true,
                :StorageMinDurationConstraint => true,
                :StorageMaxDurationConstraint => true,
                :BalanceConstraint => true
            )
        ),
        :edges => Dict{Symbol,Any}(
            :charge_edge => Dict{Symbol,Any}(
                :type => "Electricity",
                :start_vertex => missing,
                :unidirectional => true,
                :has_capacity => false,
                :efficiency => 0.9,
                :variable_om_cost => 0.0,
            ),
            :discharge_edge => Dict{Symbol,Any}(
                :type => "Electricity",
                :end_vertex => missing,
                :unidirectional => true,
                :has_capacity => true,
                :existing_capacity => 0.0,
                :can_expand => true,
                :can_retire => false,
                :efficiency => 0.9,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                    :StorageDischargeLimitConstraint => true,
                    :RampingLimitConstraint => true
                )
            ),
        ),
    )
end

"""
    make(::Type{Battery}, data::AbstractDict{Symbol, Any}, system::System) -> Battery

    Necessary data fields:
     - storage: Dict{Symbol, Any}
        - id: String
        - commodity: String
        - can_retire: Bool
        - can_expand: Bool
        - existing_capacity: Float64
        - investment_cost: Float64
        - fixed_om_cost: Float64
        - loss_fraction: Float64
        - min_duration: Float64
        - max_duration: Float64
        - min_storage_level: Float64
        - min_capacity: Float64
        - max_capacity: Float64
        - constraints: Vector{AbstractTypeConstraint}
     - edges: Dict{Symbol, Any}
        - charge_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - efficiency: Float64
        - discharge_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - efficiency
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{Battery}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(Battery, id), data)

    ## Storage component of the battery
    storage_key = :storage
    if haskey(data, storage_key)
        loaded_storage_data = Dict{Symbol,Any}(
            key => get_from([
                    (data, Symbol("storage_", key)),
                    (data[storage_key], Symbol("storage_", key)),
                    (data[storage_key], key)],
                missing)
            for key in keys(data[storage_key])
        )
    else
        loaded_storage_data = Dict{Symbol,Any}(
            key => get(data, Symbol("storage_", key), missing) for key in keys(data[storage_key])
        )
    end
    remove_missing!(loaded_storage_data)
    merge!(data[storage_key], loaded_storage_data)
    storage_data = process_data(data[storage_key])
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    default_constraints = [
        BalanceConstraint(),
        StorageCapacityConstraint(),
        StorageSymmetricCapacityConstraint(),
    ]
    # Check if the storage is a long duration storage
    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    # If storage is long duration, add the corresponding constraint
    if long_duration
        push!(default_constraints, LongDurationStorageImplicitMinMaxConstraint())
    end
    # Create the storage component of the battery
    battery_storage = StorageType(
        Symbol(id, "_", storage_key),
        storage_data,
        system.time_data[commodity_symbol],
        commodity,
    )
    battery_storage.constraints = get(storage_data, :constraints, default_constraints)

    ## Charge data of the battery
    charge_edge_key = :charge_edge
    if haskey(data, :edges) && haskey(data[:edges], charge_edge_key)
        loaded_charge_edge_data = Dict{Symbol,Any}(
            key => get_from([
                    (data, Symbol("charge_", key)),
                    (data[:edges][charge_edge_key], Symbol("charge_", key)),
                    (data[:edges][charge_edge_key], key)],
                missing)
            for key in keys(data[:edges][charge_edge_key])
        )
    else
        loaded_charge_edge_data = Dict{Symbol,Any}(
            key => get(data, Symbol("charge_", key), missing) for key in keys(data[:edges][charge_edge_key])
        )
    end
    remove_missing!(loaded_charge_edge_data)
    merge!(data[:edges][charge_edge_key], loaded_charge_edge_data)
    charge_edge_data = process_data(data[:edges][charge_edge_key])
    start_vertex = get_from([(data, :location), (charge_edge_data, :start_vertex)], missing)
    charge_edge_data[:start_vertex] = start_vertex
    charge_start_node = find_node(system.locations, Symbol(start_vertex), commodity)
    charge_end_node = battery_storage
    battery_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        charge_start_node,
        charge_end_node,
    )
    battery_charge.unidirectional = get(charge_edge_data, :unidirectional, true)

    ## Discharge output of the battery
    discharge_edge_key = :discharge_edge
    if haskey(data, :edges) && haskey(data[:edges], discharge_edge_key)
        loaded_disharge_edge_data = Dict{Symbol,Any}(
            key => get_from([
                    (data, Symbol("discharge_", key)),
                    (data[:edges][discharge_edge_key], Symbol("discharge_", key)),
                    (data[:edges][discharge_edge_key], key)],
                missing)
            for key in keys(data[:edges][discharge_edge_key])
        )
    else
        loaded_disharge_edge_data = Dict{Symbol,Any}(
            key => get(data, Symbol("discharge_", key), missing) for key in keys(data[:edges][discharge_edge_key])
        )
    end
    remove_missing!(loaded_disharge_edge_data)
    merge!(data[:edges][discharge_edge_key], loaded_disharge_edge_data)
    discharge_edge_data = process_data(data[:edges][discharge_edge_key])
    discharge_start_node = battery_storage
    end_vertex = get_from([(data, :location), (discharge_edge_data, :end_vertex)], missing)
    discharge_edge_data[:end_vertex] = end_vertex
    discharge_end_node = find_node(system.locations, Symbol(end_vertex), commodity)
    battery_discharge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        discharge_start_node,
        discharge_end_node,
    )
    battery_discharge.constraints = get(
        discharge_edge_data,
        :constraints,
        [CapacityConstraint(), StorageDischargeLimitConstraint(), RampingLimitConstraint()],
    )
    battery_discharge.unidirectional = get(discharge_edge_data, :unidirectional, true)

    battery_storage.discharge_edge = battery_discharge
    battery_storage.charge_edge = battery_charge
    discharge_efficiency = get_from([
            (data, :discharge_efficiency),
            (discharge_edge_data, :discharge_efficiency),
            (discharge_edge_data, :efficiency)], 0.9)
    charge_efficiency = get_from([
            (data, :charge_efficiency),
            (charge_edge_data, :charge_efficiency),
            (charge_edge_data, :efficiency)], 0.9)
    battery_storage.balance_data = Dict(
        :storage => Dict(
            battery_discharge.id => 1 / discharge_efficiency,
            battery_charge.id => charge_efficiency,
        ),
    )

    return Battery(id, battery_storage, battery_discharge, battery_charge)
end
