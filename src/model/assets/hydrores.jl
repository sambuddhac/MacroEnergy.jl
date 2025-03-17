struct HydroRes <: AbstractAsset
    id::AssetId
    hydrostor::AbstractStorage{Electricity}
    discharge_edge::Edge{Electricity}
    inflow_edge::Edge{Electricity}
    spill_edge::Edge{Electricity}
end

function default_data(::Type{HydroRes}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :storage => @storage_data(
            :commodity => Electricity,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :discharge_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true
                ),
            ),
            :inflow_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :MustRunConstraint => true,
                ),
            ),
            :spill_edge => @edge_data(
                :commodity => "Electricity",
            ),
        ),
    )
end

"""
    make(::Type{HydroRes}, data::AbstractDict{Symbol, Any}, system::System) -> HydroRes
"""

function make(::Type{HydroRes}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    data = recursive_merge(default_data(HydroRes, id), data)

    ## Storage component of the hydro reservoir
    storage_key = :storage
    @process_data(
        storage_data,
        data[storage_key],
        [
            (data[storage_key], key),
            (data[storage_key], Symbol("storage_", key)),
            (data, Symbol("storage_", key)),
        ]
    )
    default_constraints = [BalanceConstraint()]
    # check if the storage is a long duration storage
    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    # if storage is long duration, add the corresponding constraint
    if long_duration
        default_constraints = [BalanceConstraint(), LongDurationStorageImplicitMinMaxConstraint()]
    end
    # create the storage component of the hydro reservoir
    hydrostor = StorageType(
        Symbol(id, "_", storage_key),
        storage_data,
        system.time_data[:Electricity],
        Electricity,
    )
    hydrostor.constraints = get(storage_data, :constraints, default_constraints)

    discharge_edge_key = :discharge_edge
    @process_data(
        discharge_edge_data,
        data[:edges][discharge_edge_key],
        [
            (data[:edges][discharge_edge_key], key),
            (data[:edges][discharge_edge_key], Symbol("discharge_", key)),
            (data, Symbol("discharge_", key)),
        ]
    )
    discharge_start_node = hydrostor
    @end_vertex(
        discharge_end_node,
        discharge_edge_data,
        Electricity,
        [(discharge_edge_data, :end_vertex), (data, :location)],
    )
    discharge_edge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[:Electricity],
        Electricity,
        discharge_start_node,
        discharge_end_node,
    )
    discharge_edge.unidirectional = true;
    discharge_edge.has_capacity = true;
    discharge_edge.constraints = get(discharge_edge_data, :constraints,Vector{AbstractTypeConstraint}());

    inflow_edge_key = :inflow_edge
    @process_data(
        inflow_edge_data,
        data[:edges][inflow_edge_key],
        [
            (data[:edges][inflow_edge_key], key),
            (data[:edges][inflow_edge_key], Symbol("inflow_", key)),
            (data, Symbol("inflow_", key)),
        ]
    )
    @start_vertex(
        inflow_start_node,
        inflow_edge_data,
        Electricity,
        [(inflow_edge_data, :start_vertex), (data, :hydro_source), (data, :location),],
    )
    inflow_end_node = hydrostor
    inflow_edge = Edge(
        Symbol(id, "_", inflow_edge_key),
        inflow_edge_data,
        system.time_data[:Electricity],
        Electricity,
        inflow_start_node,
        inflow_end_node,
    )
    inflow_edge.unidirectional = true;
    inflow_edge.has_capacity = true;
    inflow_edge.can_retire = discharge_edge.can_retire;
    inflow_edge.can_expand = discharge_edge.can_expand;
    inflow_edge.existing_capacity = discharge_edge.existing_capacity;
    inflow_edge.capacity_size = discharge_edge.capacity_size;
    inflow_edge.constraints = get(discharge_edge_data, :constraints,[StorageChargeDischargeRatioConstraint();MustRunConstraint()]); 

    spill_edge_key = :spill_edge
    @process_data(
        spill_edge_data,
        data[:edges][spill_edge_key],
        [
            (data[:edges][spill_edge_key], key),
            (data[:edges][spill_edge_key], Symbol("spill_", key)),
            (data, Symbol("spill_", key)),
        ]
    )
    spill_start_node = hydrostor
    @end_vertex(
        spill_end_node,
        spill_edge_data,
        Electricity,
        [(spill_edge_data, :end_vertex), (data, :hydro_source), (data, :location),],
    )
    spill_end_node = find_node(system.locations, Symbol(spill_edge_data[:end_vertex]))
    spill_edge = Edge(
        Symbol(id, "_", spill_edge_key),
        spill_edge_data,
        system.time_data[:Electricity],
        Electricity,
        spill_start_node,
        spill_end_node,
    )
    spill_edge.unidirectional = true;
    spill_edge.has_capacity = false;
    spill_edge.constraints = get(spill_edge_data, :constraints,Vector{AbstractTypeConstraint}());

    hydrostor.discharge_edge = discharge_edge
    hydrostor.charge_edge = inflow_edge
    hydrostor.spillage_edge = spill_edge

    hydrostor.balance_data = Dict(
        :storage => Dict(
            discharge_edge.id => 1.0,
            inflow_edge.id => 1.0,
            spill_edge.id => 1.0
        )
    )

    return HydroRes(id,hydrostor,discharge_edge,inflow_edge,spill_edge)
end
