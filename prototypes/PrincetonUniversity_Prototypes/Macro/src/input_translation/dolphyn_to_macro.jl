function _get_resourcetype_names()
    return (
        :solar_photovoltaic,
        :utilitypv_losangeles_mid_100_0_2,
        :utilitypv_losangeles_mid_80_0_2,
        :onshore_wind_turbine,
        :landbasedwind_ltrg1_mid_110,
        :landbasedwind_ltrg1_mid_130,
        :offshore_wind_turbine,
        :offshorewind_otrg3_mid_fixed_1_176_77,
        :conventional_hydroelectric,
        :small_hydroelectric,
    )
end

function _get_storagetype_names()
    return (:battery_mid, :hydroelectric_pumped_storage, :hydrogen_storage)
end

function _get_transformationtype_names()
    return (
        :biomass,
        :heat_load_shifting,
        :hydroelectric_pumped_storage,
        :natural_gas_fired_combined_cycle,
        :natural_gas_fired_combustion_turbine,
        :natural_gas_steam_turbine,
        :naturalgas_ccavgcf_mid,
        :naturalgas_ccccsavgcf_mid,
        :naturalgas_ccs100_mid,
        :naturalgas_ctavgcf_mid,
    )
end

function create_nodes_from_dolphyn(
    dolphyn_inputs::Dict,
    commodity,
    time_interval::StepRange{Int64,Int64},
)
    # read number of nodes and demand from dolphyn inputs
    n_nodes = dolphyn_inputs["Z"]
    demand = dolphyn_inputs["pD"]
    fuel_price = zeros(length(time_interval)) # TODO: get this from dolphyn_inputs
    # select only the time interval of interest
    demand = demand[first(time_interval):last(time_interval), :]
    # create nodes
    nodes = Vector{Node}()
    for i = 1:n_nodes
        node = Node{commodity}(;
            id = Symbol("node_", i),
            demand = demand[:, i],
            fuel_price = fuel_price,
            time_interval = time_interval,
        )
        push!(nodes, node)
    end
    return nodes
end

function create_networks_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity,
    time_interval::StepRange{Int64,Int64},
)
    # TODO: implement this
    return
end

function create_resource(
    row::DataFrameRow,
    node::Node,
    commodity,
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)

    return Resource{commodity}(;
        node = node,
        time_interval = time_interval,
        subperiods = subperiods,
        row...,
    )
end

function create_resources_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity,
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # resources available in macro
    resource_names = _get_resourcetype_names()
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfGen"]
    # get map from dolphyn columns to macro attributes
    all_attrs = doplhyn_cols_to_macro_attrs()
    # select only the attributes that are part of a resource struct
    res_attr = intersect(propertynames(all_attrs), fieldnames(Resource))
    # swap keys and values
    all_attrs = Dict(all_attrs[key] => key for key in res_attr)

    # select only the columns of interest
    data = rename(dfGen, pairs(all_attrs))[:, res_attr]
    data[!, :id] = Symbol.(data[!, :id])

    resources = Vector{Resource}()
    # create resource
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        resource_name = row.id
        if resource_name in resource_names
            node = nodes[zones[i]]  # select the correct node
            resource = create_resource(row, node, commodity, time_interval, subperiods)
            push!(resources, resource)
        end
    end
    return resources
end

function create_symmetric_storage(
    row::DataFrameRow,
    node::Node,
    commodity,
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # create symmetric storage
    return SymmetricStorage{commodity}(;
        node = node,
        time_interval = time_interval,
        subperiods = subperiods,
        row...,
    )
end

function create_storage_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity,
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # resources available in macro
    storage_names = _get_storagetype_names()
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfGen"]

    # get map from dolphyn columns to macro attributes
    all_attrs = doplhyn_cols_to_macro_attrs()
    # select only the attributes that are part of a symmetric storage struct
    syms_attr = intersect(propertynames(all_attrs), fieldnames(SymmetricStorage))

    # swap keys and values
    all_attrs = Dict(all_attrs[key] => key for key in syms_attr)

    # select only the columns of interest
    data = rename(dfGen, pairs(all_attrs))[:, syms_attr]
    data[!, :id] = Symbol.(data[!, :id])

    sym_storage = Vector{SymmetricStorage}()
    asym_storage = Vector{AsymmetricStorage}()
    # create storage
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        resource_name = row.id
        if resource_name in storage_names
            node = nodes[zones[i]]  # select the correct node
            # if storage is symmetric, create a SymmetricStorage and push it to sym_storage
            dfGen[i, :STOR] == 1 && push!(
                sym_storage,
                create_symmetric_storage(row, node, commodity, time_interval, subperiods),
            )
            # if storage is asymmetric, create an AsymmetricStorage and push it to asym_storage
            dfGen[i, :STOR] == 2 && push!(
                asym_storage,
                create_asymmetric_storage(row, node, commodity, time_interval, subperiods),
            )
        end
    end
    return Storage(sym_storage, asym_storage)
end

# NOTE 1: right now, this is for electricy only
# NOTE 2: TODO: remove double renaming of columns
function dolphyn_to_macro(dolphyn_inputs::Dict, macro_settings::NamedTuple)

    commodity = Electricity
    period_length = macro_settings.PeriodLength

    # commodity-specific settings
    commodity_settings = macro_settings.Commodities["Electricity"]
    hours_per_timestep = commodity_settings["HoursPerTimeStep"]
    hours_per_subperiod = commodity_settings["HoursPerSubperiod"]
    time_interval = 1:hours_per_timestep:period_length
    subperiods = collect(
        Iterators.partition(time_interval, Int(hours_per_subperiod / hours_per_timestep)),
    )

    # Data structures to store input data
    node_d = Dict()
    network_d = Dict()
    resource_d = Dict()
    storage_d = Dict()

    # load nodes
    nodes = create_nodes_from_dolphyn(dolphyn_inputs, commodity, time_interval)
    node_d[Electricity] = nodes

    # load networks
    network_d[Electricity] =
        create_networks_from_dolphyn(dolphyn_inputs, nodes, commodity, time_interval)

    # load resources
    resource_d[Electricity] = create_resources_from_dolphyn(
        dolphyn_inputs,
        nodes,
        commodity,
        time_interval,
        subperiods,
    )

    # load storage
    storage_d[Electricity] = create_storage_from_dolphyn(
        dolphyn_inputs,
        nodes,
        commodity,
        time_interval,
        subperiods,
    )

    # load transformation

    @info "Dolphyn data successfully read in into MACRO"
    return InputData(macro_settings, node_d, network_d, resource_d, storage_d)
end

function doplhyn_cols_to_macro_attrs()
    return (
        id = :Resource_Type,
        cap_size = :Cap_Size,
        min_capacity = :Min_Cap_MW,
        max_capacity = :Max_Cap_MW,
        min_capacity_storage = :Min_Cap_MWh,
        max_capacity_storage = :Max_Cap_MWh,
        existing_capacity = :Existing_Cap_MW,
        existing_capacity_storage = :Existing_Cap_MWh,
        # can_expand = :Can_Expand, # TODO: check this
        # can_retire = :Can_Retire, # TODO: check this
        investment_cost = :Inv_Cost_per_MWyr,
        investment_cost_storage = :Inv_Cost_per_MWhyr,
        investment_cost_charge = :Inv_Cost_Charge_per_MWyr,
        fixed_om_cost = :Fixed_OM_Cost_per_MWyr,
        fixed_om_cost_storage = :Fixed_OM_Cost_per_MWhyr,
        fixed_om_cost_charge = :Fixed_OM_Cost_Charge_per_MWyr,
        variable_om_cost = :Var_OM_Cost_per_MWh,
        # variable_om_cost_storage, # TODO: check this
        # variable_om_cost_charge, # TODO: check this
        efficiency_charge = :Eff_Up,
        efficiency_discharge = :Eff_Down,
        min_duration = :Min_Duration,
        max_duration = :Max_Duration,
        self_discharge = :Self_Disch,
        # min_storage_level TODO: ask Filippo about this
        # TODO: asymmetric storage?
    )
end
