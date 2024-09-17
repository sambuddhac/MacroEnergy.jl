struct Battery <: AbstractAsset
    id::AssetId
    battery_transform::Storage{Electricity}
    discharge_edge::Edge{Electricity}
    charge_edge::Edge{Electricity}
end

function default_parameters(::Type{Battery})
    return Dict(
        # :id => "battery",
        :battery_transform => Dict(
            :id => "battery_storage",
            :commodity => "electricity",
            :can_retire => true,
            :can_expand => true,
            :existing_capacity_storage => 0.0,
            :investment_cost_storage => 0.0,
            :fixed_om_cost_storage => 0.0,
            :storage_loss_fraction => 0.0,
            :min_duration => 0.0,
            :max_duration => 0.0,
            :min_storage_level => 0.0,
            :min_capacity_storage => 0.0,
            :max_capacity_storage => 0.0,
            :constraints => [],
        ),
        :edges => Dict(
            :charge_edge => Dict(
                :id => "battery_charge_edge",
                :start_vertex => "node",
                :unidirectional => true,
                :has_planning_variables => false,
                :efficiency => 0.9,
            ),
            :discharge_edge => Dict(
                :id => "battery_discharge_edge",
                :end_vertex => "node",
                :unidirectional => true,
                :has_planning_variables => false,
                :can_retire => true,
                :can_expand => true,
                :efficiency => 0.9,
                :constraints => [],
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
        - existing_capacity_storage: Float64
        - investment_cost_storage: Float64
        - fixed_om_cost_storage: Float64
        - storage_loss_fraction: Float64
        - min_duration: Float64
        - max_duration: Float64
        - min_storage_level: Float64
        - min_capacity_storage: Float64
        - max_capacity_storage: Float64
        - constraints: Vector{AbstractTypeConstraint}
     - edges: Dict{Symbol, Any}
        - charge_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - efficiency: Float64
        - discharge_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - efficiency
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{Battery}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    storage_key = :storage
    storage_data = process_data(data[storage_key])
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    battery_storage =
        Storage(
            Symbol(id, "_", storage_key), 
            storage_data, 
            system.time_data[commodity_symbol], 
            commodity
        )
    battery_storage.constraints = get(
        storage_data,
        :constraints,
        [
            BalanceConstraint(),
            StorageCapacityConstraint(),
            StorageMaxDurationConstraint(),
            StorageMinDurationConstraint(),
            StorageSymmetricCapacityConstraint(),
        ],
    )

    charge_edge_key = :charge_edge
    charge_edge_data = process_data(data[:edges][charge_edge_key])
    charge_start_node = find_node(system.locations, Symbol(charge_edge_data[:start_vertex]))
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

    discharge_edge_key = :discharge_edge
    discharge_edge_data = process_data(data[:edges][discharge_edge_key])
    discharge_start_node = battery_storage
    discharge_end_node =
        find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
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
        [CapacityConstraint(), RampingLimitConstraint()],
    )
    battery_discharge.unidirectional = get(discharge_edge_data, :unidirectional, true)

    battery_storage.discharge_edge = battery_discharge
    battery_storage.charge_edge = battery_charge
    battery_storage.balance_data = Dict(
        :storage => Dict(
            battery_discharge.id => 1 / get(discharge_edge_data, :efficiency, 0.9),
            battery_charge.id => get(charge_edge_data, :efficiency, 0.9),
        ),
    )

    return Battery(id, battery_storage, battery_discharge, battery_charge)
end
