struct GasStorage{T} <: AbstractAsset
    id::AssetId
    gas_storage::AbstractStorage{T}
    compressor_transform::Transformation
    discharge_edge::Edge{T}
    charge_edge::Edge{T}
    compressor_elec_edge::Edge{Electricity}
    compressor_gas_edge::Edge{T}
end

GasStorage(id::AssetId,gas_storage::AbstractStorage{T},compressor_transform::Transformation,discharge_edge::Edge{T},charge_edge::Edge{T},compressor_elec_edge::Edge{Electricity},
compressor_gas_edge::Edge{T}) where T<:Commodity =
    GasStorage{T}(id,gas_storage,compressor_transform,discharge_edge,charge_edge,compressor_elec_edge,
    compressor_gas_edge)

function default_data(::Type{GasStorage}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :storage => @storage_data(
            :commodity => missing,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
                :StorageCapacityConstraint => true,
            ),
        ),
        :transforms => @transform_data(
            :timedata => "Electricity",
            :electricity_consumption => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :compressor_elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :compressor_gas_edge => @edge_data(
                :commodity => missing,
            ),
            :charge_edge => @edge_data(
                :commodity => missing,
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :discharge_edge => @edge_data(
                :commodity => missing,
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
        ),
    )
end

function make(::Type{GasStorage}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(GasStorage, id), data)

    ## Storage component of the gas storage
    gas_storage_key = :storage
    @process_data(
        storage_data,
        data[gas_storage_key],
        [
            (data, Symbol("storage_", key)),
            (data[gas_storage_key], key),
            (data[gas_storage_key], Symbol("storage_", key)),
        ],
    )
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = commodity_types()[commodity_symbol]

    default_constraints = [
        BalanceConstraint(),
        StorageCapacityConstraint(),
    ]
    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    if long_duration
        push!(default_constraints, LongDurationStorageImplicitMinMaxConstraint())
    end
    # create the storage component of the gas storage
    gas_storage = StorageType(
        Symbol(id, "_", gas_storage_key),
        storage_data,
        system.time_data[commodity_symbol],
        commodity,
    )
    gas_storage.constraints = get(storage_data, :constraints, default_constraints)

    ## Compressor component of the gas storage
    compressor_key = :transforms
    @process_data(
        transform_data,
        data[compressor_key],
        [
            (data, Symbol("transform_", key)),
            (data[compressor_key], key),
            (data[compressor_key], Symbol("transform_", key)),
        ],
    )
    compressor_transform = Transformation(;
        id = Symbol(id, "_", compressor_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    compressor_elec_edge_key = :compressor_elec_edge
    @process_data(
        compressor_elec_edge_data,
        data[:edges][compressor_elec_edge_key],
        [
            (data, Symbol("elec_", key)),
            (data[:edges][compressor_elec_edge_key], key),
            (data[:edges][compressor_elec_edge_key], Symbol("elec_", key)),
        ],
    )
    @start_vertex(
        elec_start_node,
        compressor_elec_edge_data,
        Electricity,
        [(data, :location), (compressor_elec_edge_data, :start_vertex)],
    )
    elec_end_node = compressor_transform
    compressor_elec_edge = Edge(
        Symbol(id, "_", compressor_elec_edge_key),
        compressor_elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    compressor_elec_edge.unidirectional = true;

    compressor_gas_edge_key = :compressor_gas_edge
    @process_data(
        compressor_gas_edge_data,
        data[:edges][compressor_gas_edge_key],
        [
            (data, Symbol("gas_", key)),
            (data[:edges][compressor_gas_edge_key], key),
            (data[:edges][compressor_gas_edge_key], Symbol("gas_", key)),
        ],
    )
    @start_vertex(
        gas_edge_start_node,
        compressor_gas_edge_data,
        commodity,
        [(data, :location), (compressor_gas_edge_data, :start_vertex)],
    )
    gas_edge_end_node = compressor_transform
    compressor_gas_edge = Edge(
        Symbol(id, "_", compressor_gas_edge_key),
        compressor_gas_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        gas_edge_start_node,
        gas_edge_end_node,
    )
    compressor_gas_edge.unidirectional = true;

    charge_edge_key = :charge_edge
    @process_data(
        charge_edge_data,
        data[:edges][charge_edge_key],
        [
            (data, Symbol("charge_", key)),
            (data[:edges][charge_edge_key], key),
            (data[:edges][charge_edge_key], Symbol("charge_", key)),
        ],
    )
    charge_start_node = compressor_transform
    charge_end_node = gas_storage
    gas_storage_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        charge_start_node,
        charge_end_node,
    )
    gas_storage_charge.unidirectional = true;
    gas_storage_charge.constraints =
        get(charge_edge_data, :constraints, [CapacityConstraint()])

    discharge_edge_key = :discharge_edge
    @process_data(
        discharge_edge_data,
        data[:edges][discharge_edge_key],
        [
            (data, Symbol("discharge_", key)),
            (data[:edges][discharge_edge_key], key),
            (data[:edges][discharge_edge_key], Symbol("discharge_", key)),
        ],
    )
    discharge_start_node = gas_storage
    @end_vertex(
        discharge_end_node,
        discharge_edge_data,
        commodity,
        [(data, :location), (discharge_edge_data, :end_vertex)],
    )
    gas_storage_discharge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        discharge_start_node,
        discharge_end_node,
    )
    gas_storage_discharge.constraints = get(
        discharge_edge_data,
        :constraints,
        [CapacityConstraint()],
    )
    gas_storage_discharge.unidirectional = true;
    gas_storage.discharge_edge = gas_storage_discharge
    gas_storage.charge_edge = gas_storage_charge

    gas_storage.balance_data = Dict(
        :storage => Dict(
            gas_storage_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
            gas_storage_charge.id => get(charge_edge_data, :efficiency, 1.0),
        ),
    )

    compressor_transform.balance_data = Dict(
        :electricity => Dict(
            compressor_elec_edge.id => 1.0,
            gas_storage_charge.id => get(transform_data, :electricity_consumption, 0.0),
        ),
        :hydrogen => Dict(
            gas_storage_charge.id => 1.0,
            compressor_gas_edge.id => 1.0
        ),
    )

    return GasStorage(
        id,
        gas_storage,
        compressor_transform,
        gas_storage_discharge,
        gas_storage_charge,
        compressor_elec_edge,
        compressor_gas_edge,
    )
end
