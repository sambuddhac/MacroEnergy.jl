struct H2Storage <: AbstractAsset
    h2storage_transform::Storage{Hydrogen}
    compressor_transform::Transformation
    discharge_edge::Edge{Hydrogen}
    charge_edge::Edge{Hydrogen}
    compressor_elec_edge::Edge{Electricity}
    compressor_h2_edge::Edge{Hydrogen}
end

id(b::H2Storage) = b.h2storage_transform.id

function make(::Type{H2Storage}, data::AbstractDict{Symbol, Any}, system::System)
    storage_data = validate_data(data[:storage])

    h2storage= Storage{Hydrogen}(;
        id = Symbol(storage_data[:id]),
        timedata = system.time_data[:Hydrogen],
        can_retire = get(storage_data, :can_retire, false),
        can_expand = get(storage_data, :can_expand, false),
        existing_capacity_storage = get(storage_data, :existing_capacity_storage, 0.0),
        investment_cost_storage = get(storage_data, :investment_cost_storage, 0.0),
        fixed_om_cost_storage = get(storage_data, :fixed_om_cost_storage, 0.0),
        storage_loss_fraction = get(storage_data, :storage_loss_fraction, 0.0),
        min_storage_level = get(storage_data, :min_storage_level, 0.0),
        min_capacity_storage = get(storage_data, :min_capacity_storage, 0.0),
        max_capacity_storage = get(storage_data, :max_capacity_storage, Inf),
        constraints = get(storage_data, :constraints, [BalanceConstraint(), StorageCapacityConstraint(), MinStorageLevelConstraint()])
    )

    transform_data = validate_data(data[:transforms])
    compressor_transform = Transformation(;
    id = Symbol(transform_data[:id]),
    timedata = system.time_data[Symbol(transform_data[:time_commodity])],
    constraints = get(transform_data, :constraints, [BalanceConstraint()])
    )

    compressor_elec_edge_data = validate_data(data[:edges][:compressor_elec])
    elec_start_node = find_node(system.locations, Symbol(compressor_elec_edge_data[:start_vertex]))
    elec_end_node = compressor_transform;
    compressor_elec_edge = Edge(Symbol(compressor_elec_edge_data[:id]),compressor_elec_edge_data, system.time_data[:Electricity],Electricity, elec_start_node,  elec_end_node)
    compressor_elec_edge.unidirectional = get(compressor_elec_edge_data, :unidirectional, true);

    compressor_h2_edge_data = validate_data(data[:edges][:compressor_h2])
    h2_start_node = find_node(system.locations, Symbol(compressor_h2_edge_data[:start_vertex]))
    h2_end_node = compressor_transform;
    compressor_h2_edge = Edge(Symbol(compressor_h2_edge_data[:id]),compressor_h2_edge_data, system.time_data[:Hydrogen],Hydrogen, h2_start_node,  h2_end_node)
    compressor_h2_edge.unidirectional = get(compressor_h2_edge_data, :unidirectional, true);

    charge_edge_data = validate_data(data[:edges][:charge])
    charge_start_node =  compressor_transform;
    charge_end_node =   h2storage;
    h2storage_charge = Edge(Symbol(data[:id] * "_charge"),charge_edge_data, system.time_data[:Hydrogen],Hydrogen, charge_start_node,  charge_end_node)
    h2storage_charge.unidirectional = get(charge_edge_data, :unidirectional, true);
    h2storage_charge.constraints = get(charge_edge_data,:constraints,[CapacityConstraint()])

    discharge_edge_data = validate_data(data[:edges][:discharge])
    discharge_start_node = h2storage
    discharge_end_node = find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    h2storage_discharge = Edge(Symbol(data[:id] * "_discharge"),discharge_edge_data, system.time_data[:Hydrogen],Hydrogen, discharge_start_node,  discharge_end_node);
    h2storage_discharge.constraints = get(discharge_edge_data,:constraints,[CapacityConstraint(), RampingLimitConstraint()])
    h2storage_discharge.unidirectional = get(discharge_edge_data, :unidirectional, true);

    h2storage.discharge_edge = h2storage_discharge
    h2storage.charge_edge = h2storage_charge

    h2storage.balance_data =  Dict(:storage=>Dict(h2storage_discharge.id=>1/get(discharge_edge_data,:efficiency,1.0),
                                                h2storage_charge.id=>get(charge_edge_data,:efficiency,1.0)))

    compressor_transform.balance_data = Dict(:electricity=>Dict(compressor_h2_edge.id=>get(transform_data,:electricity_consumption,0.0),
                                                compressor_elec_edge.id => 1.0,
                                                h2storage_charge.id=>0.0),
                                            :hydrogen=>Dict(h2storage_charge.id=>1.0,
                                                            compressor_h2_edge.id => 1.0,
                                                            compressor_elec_edge.id=>0.0),
                                        )

    return H2Storage(h2storage,compressor_transform,h2storage_discharge,h2storage_charge,compressor_elec_edge,compressor_h2_edge)
end