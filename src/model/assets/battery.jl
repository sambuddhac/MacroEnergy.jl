struct Battery <: AbstractAsset
    battery_transform::Storage{Electricity}
    discharge_edge::Edge{Electricity}
    charge_edge::Edge{Electricity}
end

id(b::Battery) = b.battery_transform.id

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
        - charge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - efficiency: Float64
        - discharge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - efficiency
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{Battery}, data::AbstractDict{Symbol, Any}, system::System)
    storage_data = validate_data(data[:storage])
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    battery_storage = Storage{commodity}(;
        id = Symbol(storage_data[:id] * "_storage"),
        timedata = system.time_data[commodity_symbol],
        can_retire = get(storage_data, :can_retire, false),
        can_expand = get(storage_data, :can_expand, false),
        existing_capacity_storage = get(storage_data, :existing_capacity_storage, 0.0),
        investment_cost_storage = get(storage_data, :investment_cost_storage, 0.0),
        fixed_om_cost_storage = get(storage_data, :fixed_om_cost_storage, 0.0),
        storage_loss_fraction = get(storage_data, :storage_loss_fraction, 0.0),
        min_duration = get(storage_data, :min_duration, 0.0),
        max_duration = get(storage_data, :max_duration, 0.0),
        min_storage_level = get(storage_data, :min_storage_level, 0.0),
        min_capacity_storage = get(storage_data, :min_capacity_storage, 0.0),
        max_capacity_storage = get(storage_data, :max_capacity_storage, Inf),
        balance_data = get(storage_data, :balance_data, Dict(:storage=>Dict(:discharge=>1/0.9,:charge=>0.9))),
        constraints = get(storage_data, :constraints, [BalanceConstraint(), StorageCapacityConstraint(), StorageMaxDurationConstraint(), StorageMinDurationConstraint(), StorageSymmetricCapacityConstraint()])
    )

    charge_edge_data = validate_data(data[:edges][:charge])
    charge_start_node = find_node(system.locations, Symbol(charge_edge_data[:start_vertex]))
    charge_end_node = battery_storage
    battery_charge = Edge(Symbol(data[:id] * "_charge"),charge_edge_data, system.time_data[commodity_symbol],commodity, charge_start_node,  charge_end_node)
    battery_charge.unidirectional = get(charge_edge_data, :unidirectional, true);

    discharge_edge_data = validate_data(data[:edges][:discharge])
    discharge_start_node = battery_storage
    discharge_end_node = find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    battery_discharge = Edge(Symbol(data[:id] * "_discharge"),discharge_edge_data, system.time_data[commodity_symbol],commodity, discharge_start_node,  discharge_end_node);
    battery_discharge.constraints = get(discharge_edge_data,:constraints,[CapacityConstraint(), RampingLimitConstraint()])
    battery_discharge.unidirectional = get(discharge_edge_data, :unidirectional, true);

    battery_storage.discharge_edge = battery_discharge
    battery_storage.charge_edge = battery_charge
    battery_storage.balance_data =  Dict(:storage=>
                                            Dict(battery_discharge.id=>1/get(discharge_edge_data,:efficiency,0.9),
                                                battery_charge.id=>get(charge_edge_data,:efficiency,0.9)))

    return Battery(battery_storage, battery_discharge, battery_charge)
end