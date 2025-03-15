struct Battery <: AbstractAsset
    id::AssetId
    battery_storage::AbstractStorage{Electricity}
    discharge_edge::Edge{Electricity}
    charge_edge::Edge{Electricity}
end

function default_data(::Type{Battery}, id=missing,)
    return Dict{Symbol,Any}(
        :id => id,
        :storage => @storage_data(
            :commodity => "Electricity",
            :can_retire => false,
            :constraints => Dict{Symbol,Bool}(
                :StorageCapacityConstraint => true,
                :StorageSymmetricCapacityConstraint => true,
                :BalanceConstraint => true
            )
        ),
        :edges => Dict{Symbol,Any}(
            :charge_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :discharge_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                    :StorageDischargeLimitConstraint => true,
                    :RampingLimitConstraint => true
                )
            )
        )
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
    @process_data(storage_data, data[storage_key], [
        (data, Symbol("storage_", key)),
        (data[storage_key], Symbol("storage_", key)),
        (data[storage_key], key)
    ])
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
    @process_data(charge_edge_data, data[:edges][charge_edge_key], [
        (data, Symbol("charge_", key)),
        (data[:edges][charge_edge_key], Symbol("charge_", key)),
        (data[:edges][charge_edge_key], key)
    ])
    @start_vertex(
        charge_start_node,
        charge_edge_data,
        commodity,
        [(data, :location), (charge_edge_data, :start_vertex)],
    )
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
    @process_data(discharge_edge_data, data[:edges][discharge_edge_key], [
        (data, Symbol("discharge_", key)),
        (data[:edges][discharge_edge_key], Symbol("discharge_", key)),
        (data[:edges][discharge_edge_key], key)
    ])
    discharge_start_node = battery_storage
    @end_vertex(
        discharge_end_node,
        discharge_edge_data,
        commodity,
        [(data, :location), (discharge_edge_data, :end_vertex)],
    )
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
            (discharge_edge_data, :discharge_efficiency),
            (discharge_edge_data, :efficiency)
        ], 0.9)
    charge_efficiency = get_from([
            (charge_edge_data, :charge_efficiency),
            (charge_edge_data, :efficiency)
        ], 0.9)
    battery_storage.balance_data = Dict(
        :storage => Dict(
            battery_discharge.id => 1 / discharge_efficiency,
            battery_charge.id => charge_efficiency,
        ),
    )

    return Battery(id, battery_storage, battery_discharge, battery_charge)
end
