struct GasStorage{T} <: AbstractAsset
    id::AssetId
    gas_storage::AbstractStorage{T}
    charge_edge::Edge{T}
    discharge_edge::Edge{T}
    charge_elec_edge::Edge{Electricity}
    discharge_elec_edge::Edge{Electricity}
end

GasStorage(id::AssetId,gas_storage::AbstractStorage{T},charge_edge::Edge{T},discharge_edge::Edge{T},
charge_elec_edge::Edge{Electricity},discharge_elec_edge::Edge{Electricity}) where T<:Commodity =
    GasStorage{T}(id,gas_storage,charge_edge,discharge_edge,charge_elec_edge,discharge_elec_edge)

function default_data(t::Type{GasStorage}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{GasStorage}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :storage => @storage_data(
            :commodity => missing,
            :charge_electricity_consumption => 0.0,
            :discharge_electricity_consumption => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
                :StorageCapacityConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :charge_edge => @edge_data(
                :efficiency => 1.0,
                :commodity => missing,
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :discharge_edge => @edge_data(
                :efficiency => 1.0,
                :commodity => missing,
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :charge_elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :discharge_elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
        ),
    )
end

function make(asset_type::Type{GasStorage}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    ## Storage component of the gas storage
    gas_storage_key = :storage
    @process_data(
        storage_data,
        data[gas_storage_key],
        [
            (data[gas_storage_key], key),
            (data[gas_storage_key], Symbol("storage_", key)),
            (data, Symbol("storage_", key)),
        ],
    )

    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = commodity_types()[commodity_symbol]

    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    # create the storage component of the gas storage
    gas_storage = StorageType(
        Symbol(id, "_", gas_storage_key),
        storage_data,
        system.time_data[commodity_symbol],
        commodity,
    )
    if long_duration
        lds_constraints = [LongDurationStorageImplicitMinMaxConstraint()]
        for c in lds_constraints
            if !(c in gas_storage.constraints)
                push!(gas_storage.constraints, c)
            end
        end
    end

    ## Electricity consumption of the gas storage

    charge_elec_edge_key = :charge_elec_edge
    @process_data(
        charge_elec_edge_data,
        data[:edges][charge_elec_edge_key],
        [
            (data[:edges][charge_elec_edge_key], key),
            (data[:edges][charge_elec_edge_key], Symbol("charge_elec_", key)),
            (data, Symbol("charge_elec_", key)),
        ],
    )
    @start_vertex(
        charge_elec_start_node,
        charge_elec_edge_data,
        Electricity,
        [(charge_elec_edge_data, :start_vertex), (data, :location)],
    )
    charge_elec_end_node = gas_storage
    charge_elec_edge = Edge(
        Symbol(id, "_", charge_elec_edge_key),
        charge_elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        charge_elec_start_node,
        charge_elec_end_node,
    )

    discharge_elec_edge_key = :discharge_elec_edge
    @process_data(
        discharge_elec_edge_data,
        data[:edges][discharge_elec_edge_key],
        [
            (data[:edges][discharge_elec_edge_key], key),
            (data[:edges][discharge_elec_edge_key], Symbol("discharge_elec_", key)),
            (data, Symbol("discharge_elec_", key)),
        ],
    )
    @start_vertex(
        discharge_elec_start_node,
        discharge_elec_edge_data,
        Electricity,
        [(discharge_elec_edge_data, :start_vertex), (data, :location)],
    )
    discharge_elec_end_node = gas_storage
    discharge_elec_edge = Edge(
        Symbol(id, "_", discharge_elec_edge_key),
        discharge_elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        discharge_elec_start_node,
        discharge_elec_end_node,
    )

    charge_edge_key = :charge_edge
    @process_data(
        charge_edge_data,
        data[:edges][charge_edge_key],
        [
            (data[:edges][charge_edge_key], key),
            (data[:edges][charge_edge_key], Symbol("charge_", key)),
            (data, Symbol("charge_", key)),
        ],
    )
    @start_vertex(
        charge_start_node,
        charge_edge_data,
        commodity,
        [(charge_edge_data, :start_vertex), (data, :location)],
    )
    charge_end_node = gas_storage
    gas_storage_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        charge_start_node,
        charge_end_node,
    )

    discharge_edge_key = :discharge_edge
    @process_data(
        discharge_edge_data,
        data[:edges][discharge_edge_key],
        [
            (data[:edges][discharge_edge_key], key),
            (data[:edges][discharge_edge_key], Symbol("discharge_", key)),
            (data, Symbol("discharge_", key)),
        ],
    )
    discharge_start_node = gas_storage
    @end_vertex(
        discharge_end_node,
        discharge_edge_data,
        commodity,
        [(discharge_edge_data, :end_vertex), (data, :location)],
    )
    gas_storage_discharge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        discharge_start_node,
        discharge_end_node,
    )

    gas_storage.discharge_edge = gas_storage_discharge
    gas_storage.charge_edge = gas_storage_charge
    
    gas_storage.balance_data = Dict(
        :storage => Dict(
            gas_storage_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
            gas_storage_charge.id => get(charge_edge_data, :efficiency, 1.0),
        ),
        :charge_electricity_consumption => Dict(
            #This is multiplied by -1 because they are both edges that enters storage, 
            #so we need to get one of them on the right side of the equality balance constraint    
            charge_elec_edge.id => -1.0,
            gas_storage_charge.id => get(storage_data, :charge_electricity_consumption, 0.0), 
        ),
        :discharge_electricity_consumption => Dict(
            discharge_elec_edge.id => 1.0,
            gas_storage_discharge.id => get(storage_data, :discharge_electricity_consumption, 0.0),
        ),
    )


    return GasStorage(
        id,
        gas_storage,
        gas_storage_charge,
        gas_storage_discharge,
        charge_elec_edge,
        discharge_elec_edge
    )
end
