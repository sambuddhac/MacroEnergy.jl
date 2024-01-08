function _get_resource_types(c::Type{Electricity})
    return (
        :solar_photovoltaic,
        # :utilitypv_losangeles_mid_100_0_2,
        # :utilitypv_losangeles_mid_80_0_2,
        :onshore_wind_turbine,
        # :landbasedwind_ltrg1_mid_110,
        # :landbasedwind_ltrg1_mid_130,
        :offshore_wind_turbine,
        # :offshorewind_otrg3_mid_fixed_1_176_77,
        # :conventional_hydroelectric,
        # :small_hydroelectric,
    )
end

function _get_transformationtype_names()
    return (
        # :biomass,
        # :heat_load_shifting,
        # :hydroelectric_pumped_storage,
        :natural_gas_fired_combined_cycle,
        :natural_gas_fired_combustion_turbine,
        :natural_gas_steam_turbine,
        #:naturalgas_ccavgcf_mid,
        #:naturalgas_ccccsavgcf_mid,
        #:naturalgas_ccs100_mid,
        #:naturalgas_ctavgcf_mid,
    )
end

function create_nodes_from_dolphyn(
    dolphyn_inputs::Dict,
    commodity::Type{Electricity},
    time_interval::StepRange{Int64,Int64},
)
    # read number of nodes and demand from dolphyn inputs
    n_nodes = dolphyn_inputs["Z"]
    demand = dolphyn_inputs["pD"]
    max_nsd = dolphyn_inputs["pMax_D_Curtail"];
    price_nsd = dolphyn_inputs["pC_D_Curtail"];
    # select only the time interval of interest
    demand = demand[first(time_interval):last(time_interval), :]

    # create nodes
    nodes = Vector{Node}()
    for i in 1:n_nodes
        node = Node{commodity}(;
            id = Symbol("node_", i),
            demand = demand[:, i],
            time_interval = time_interval,
            max_nsd = max_nsd,
            price_nsd = price_nsd,
        )
        push!(nodes, node)
    end
    return nodes
end

function create_nodes_from_dolphyn(
    dolphyn_inputs::Dict,
    commodity::Type{NaturalGas},
    time_interval::StepRange{Int64,Int64},
)
   
    # read number of nodes and demand from dolphyn inputs
    n_nodes = dolphyn_inputs["Z"]
      
    # create nodes
    nodes = Vector{SourceNode}()

    for i in 1:n_nodes
        node = SourceNode{commodity}(;
        id = Symbol("node_", i),
        time_interval = time_interval
        )
        push!(nodes, node)
    end

    return nodes
end


function create_nodes_from_dolphyn(
    dolphyn_inputs::Dict,
    commodity::Type{Hydrogen},
    time_interval::StepRange{Int64,Int64},
)
    # read number of nodes and demand from dolphyn inputs
    n_nodes = dolphyn_inputs["Z"]
    demand = dolphyn_inputs["H2_D"]
    max_nsd = dolphyn_inputs["pMax_H2_D_Curtail"];
    price_nsd = dolphyn_inputs["pC_H2_D_Curtail"];
    # select only the time interval of interest
    demand = demand[first(time_interval):last(time_interval), :]

    # create nodes
    nodes = Vector{Node}()
    for i in 1:n_nodes
        node = Node{commodity}(;
            id = Symbol("node_", i),
            demand = demand[:, i],
            time_interval = time_interval,
            max_nsd = max_nsd,
            price_nsd = price_nsd,
        )
        push!(nodes, node)
    end
    return nodes
end

function create_networks_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity::Type{Electricity},
    time_interval::StepRange{Int64,Int64},
)
    number_of_edges = dolphyn_inputs["L"];
    network = Vector{Edge}()
    for i in 1:number_of_edges

        edge = Edge{commodity}(
        time_interval = time_interval,
        start_node = nodes[findfirst(dolphyn_inputs["pNet_Map"][i,:].==-1)],
        end_node = nodes[findfirst(dolphyn_inputs["pNet_Map"][i,:].==1)],
        existing_capacity = dolphyn_inputs["pTrans_Max"][i],
        unidirectional = false,
        max_line_reinforcement = dolphyn_inputs["pMax_Line_Reinforcement"][i],
        line_reinforcement_cost = dolphyn_inputs["pC_Line_Reinforcement"][i],
        can_expand = in(i,dolphyn_inputs["EXPANSION_LINES"]),
        line_loss_percentage = dolphyn_inputs["pTrans_Loss_Coef"][i],
        )

        push!(network,edge)
    end
    return network
end

function create_resources_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity::Type{Electricity},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # resources available in macro
    macro_resource_types = _get_resource_types(commodity)
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfGen"]
    # get map from dolphyn columns to macro attributes
    all_attrs = dolphyn_cols_to_macro_attrs(commodity)
    # select only the attributes that are part of a resource struct
    res_attr = intersect(propertynames(all_attrs), fieldnames(Resource))
    # swap keys and values
    all_attrs = Dict(all_attrs[key] => key for key in res_attr)

    # select only the columns of interest
    data = rename(dfGen, pairs(all_attrs))[:, res_attr]
    data[!, :id] = Symbol.(data[!, :id])
    data[!,:can_expand] = dfGen[!,:New_Build].==1;
    data[!,:can_retire] = dfGen[!,:New_Build].>=0;

    capacity_factor = dolphyn_inputs["pP_Max"];

    resources = Vector{Resource}()
    # create resource
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        resource_type = Symbol(dfGen.Resource_Type[dfGen.Resource.==string(row.id)][1]);
        if resource_type in macro_resource_types
            node = nodes[zones[i]]  # select the correct node
            resource =  Resource{commodity}(;
            node = node,
            time_interval = time_interval,
            subperiods = subperiods,
            capacity_factor = capacity_factor[i,time_interval],
            row...,
        )
            push!(resources, resource)
        end
    end
    return resources
end

function create_resources_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity::Type{NaturalGas},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    dfGen = dolphyn_inputs["dfGen"];
    fuel_costs = dolphyn_inputs["fuel_costs"];

    resources = Vector{Resource}()

    for n in 1:dolphyn_inputs["Z"]
        gen_at_node = dfGen[dfGen.Zone.==n,:];

        i = findfirst(occursin.("natural_gas",gen_at_node.Resource));

        push!(resources , Resource{commodity}(;
        node = nodes[n],
        id = Symbol(gen_at_node[i,:Fuel]),
        time_interval = time_interval,
        subperiods = subperiods,
        price = fuel_costs[gen_at_node[i,:Fuel]][time_interval],
        can_expand = false,
        can_retire = false,
        constraints = Vector{AbstractTypeConstraint}(),
        ))
    end
  
        
    return resources
end


function create_storage_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity::Type{Hydrogen},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfH2Gen"]

    # get map from dolphyn columns to macro attributes
    all_attrs = dolphyn_cols_to_macro_attrs(commodity)
    # select only the attributes that are part of a symmetric storage struct
    syms_attr = intersect(propertynames(all_attrs), union(fieldnames(SymmetricStorage),fieldnames(AsymmetricStorage)))

    # swap keys and values
    all_attrs = Dict(all_attrs[key] => key for key in syms_attr)

    # select only the columns of interest
    data = rename(dfGen, pairs(all_attrs))[:, syms_attr]
    data[!, :id] = Symbol.(data[!, :id])
    data[!,:can_expand] = dfGen[!,:New_Build].==1;
    data[!,:can_retire] = dfGen[!,:New_Build].>=0;

    sym_storage = Vector{SymmetricStorage}()
    asym_storage = Vector{AsymmetricStorage}()
    # create storage
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        node = nodes[zones[i]]  # select the correct node              
        # Create an AsymmetricStorage and push it to asym_storage
        dfGen[i, :H2_STOR] == 1 && push!(
                asym_storage,
                AsymmetricStorage{commodity}(;
                node = node,
                time_interval = time_interval,
                subperiods = subperiods,
                row...,
            ))

    end
    return Storage(sym_storage, asym_storage)
end

function create_storage_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes,
    commodity::Type{Electricity},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfGen"]

    # get map from dolphyn columns to macro attributes
    all_attrs = dolphyn_cols_to_macro_attrs(commodity)
    # select only the attributes that are part of a symmetric storage struct
    syms_attr = intersect(propertynames(all_attrs), union(fieldnames(SymmetricStorage),fieldnames(AsymmetricStorage)))

    # swap keys and values
    all_attrs = Dict(all_attrs[key] => key for key in syms_attr)

    # select only the columns of interest
    data = rename(dfGen, pairs(all_attrs))[:, syms_attr]
    data[!, :id] = Symbol.(data[!, :id])
    data[!,:can_expand] = dfGen[!,:New_Build].==1;
    data[!,:can_retire] = dfGen[!,:New_Build].>=0;

    sym_storage = Vector{SymmetricStorage}()
    asym_storage = Vector{AsymmetricStorage}()
    # create storage
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        node = nodes[zones[i]]  # select the correct node
        # if storage is symmetric, create a SymmetricStorage and push it to sym_storage
        dfGen[i, :STOR] == 1 && push!(
                sym_storage,
                SymmetricStorage{commodity}(;
                node = node,
                time_interval = time_interval,
                subperiods = subperiods,
                row...,
                ))
                
        # if storage is asymmetric, create an AsymmetricStorage and push it to asym_storage
        dfGen[i, :STOR] == 2 && push!(
                asym_storage,
                AsymmetricStorage{commodity}(;
                node = node,
                time_interval = time_interval,
                subperiods = subperiods,
                row...,
                ))
    end
    return Storage(sym_storage, asym_storage)
end

# NOTE 2: TODO: remove double renaming of columns
function dolphyn_to_macro(dolphyn_inputs::Dict,settings_path::String)

    macro_settings = configure_settings(joinpath(settings_path, "macro_settings.yml"))

    # Data structures to store input data
    node_d = Dict()
    network_d = Dict()
    resource_d = Dict()
    storage_d = Dict()

    macro_settings = (; macro_settings..., PeriodLength=dolphyn_inputs["T"])

    for commodity in commodity_type.(keys(macro_settings.Commodities))

        commodity_str = string(commodity)

        macro_settings.Commodities[commodity_str]["HoursPerSubperiod"] = dolphyn_inputs["hours_per_subperiod"];
        macro_settings.Commodities[commodity_str]["HoursPerTimeStep"] = 1;

        period_length = macro_settings.PeriodLength
        commodity_settings = macro_settings.Commodities[commodity_str]
        hours_per_timestep = commodity_settings["HoursPerTimeStep"]
        hours_per_subperiod = commodity_settings["HoursPerSubperiod"]
        time_interval = 1:hours_per_timestep:period_length
        subperiods = collect(
            Iterators.partition(time_interval, Int(hours_per_subperiod / hours_per_timestep)),
        )

        # load nodes
        nodes = create_nodes_from_dolphyn(dolphyn_inputs, commodity, time_interval)
        node_d[commodity] = nodes

        # load networks
        if commodity==Hydrogen
            # Do nothing. For now, we ignore hydrogen pipelines or other forms of H2 transportation.
        elseif commodity==NaturalGas
            # Do nothing. For now, we ignore natural gas pipelines or other forms of NG transportation.
        else
            network_d[commodity] =
                create_networks_from_dolphyn(dolphyn_inputs, nodes, commodity, time_interval)
        end

        # load resources 
        if commodity==Hydrogen
            # Do nothing. Dolphyn does not model any hydrogen resource (hydrogen is only produced from either electricity or natural gas)
        else
           resource_d[commodity] = create_resources_from_dolphyn(
                dolphyn_inputs,
                nodes,
                commodity,
                time_interval,
                subperiods,
            )
        end

        # load storage
        if commodity == NaturalGas
            # Do nothing. Dolphyn does not model natural gas storage.
        else
            storage_d[commodity] = create_storage_from_dolphyn(
            dolphyn_inputs,
            nodes,
            commodity,
            time_interval,
            subperiods,
            )
        end

        # load transformation
    end

    @info "Dolphyn data successfully read in into MACRO"

    return InputData(macro_settings, node_d, network_d, resource_d, storage_d), macro_settings
end

function dolphyn_cols_to_macro_attrs(c::Type{Electricity})
    return (
        id = :Resource,
        cap_size = :Cap_Size,
        min_capacity = :Min_Cap_MW,
        max_capacity = :Max_Cap_MW,
        min_capacity_storage = :Min_Cap_MWh,
        max_capacity_storage = :Max_Cap_MWh,
        existing_capacity = :Existing_Cap_MW,
        existing_capacity_storage = :Existing_Cap_MWh,
        investment_cost = :Inv_Cost_per_MWyr,
        investment_cost_storage = :Inv_Cost_per_MWhyr,
        investment_cost_withdrawal = :Inv_Cost_Charge_per_MWyr,
        fixed_om_cost = :Fixed_OM_Cost_per_MWyr,
        fixed_om_cost_storage = :Fixed_OM_Cost_per_MWhyr,
        fixed_om_cost_withdrawal = :Fixed_OM_Cost_Charge_per_MWyr,
        variable_om_cost = :Var_OM_Cost_per_MWh,
        variable_om_cost_withdrawal = :Var_OM_Cost_per_MWh_In, 
        efficiency_withdrawal = :Eff_Up,
        efficiency_injection = :Eff_Down,
        min_duration = :Min_Duration,
        max_duration = :Max_Duration,
        storage_loss_percentage = :Self_Disch,
    )
end

function dolphyn_cols_to_macro_attrs(c::Type{Hydrogen})
    return (
        id = :H2_Resource,
        cap_size = :Cap_Size_tonne_p_hr,
        min_capacity = :Min_Cap_tonne_p_hr,
        max_capacity = :Max_Cap_tonne_p_hr,
        min_capacity_storage = :Min_Energy_Cap_tonne,
        max_capacity_storage = :Max_Energy_Cap_tonne,
        min_capacity_withdrawal = :Min_Charge_Cap_tonne_p_hr,
        max_capacity_withdrawal = :Max_Charge_Cap_tonne_p_hr,
        existing_capacity = :Existing_Cap_tonne_p_hr,
        existing_capacity_storage = :Existing_Energy_Cap_tonne,
        existing_capacity_withdrawal = :Existing_Charge_Cap_tonne_p_hr,
        investment_cost = :Inv_Cost_p_tonne_p_hr_yr,
        investment_cost_storage = :Inv_Cost_Energy_p_tonne_yr,
        investment_cost_withdrawal = :Inv_Cost_Charge_p_tonne_p_hr_yr,
        fixed_om_cost = :Fixed_OM_Cost_p_tonne_p_hr_yr,
        fixed_om_cost_storage = :Fixed_OM_Cost_Energy_p_tonne_yr,
        fixed_om_cost_withdrawal = :Fixed_OM_Cost_Charge_p_tonne_p_hr_yr,
        variable_om_cost = :Var_OM_Cost_p_tonne,
        variable_om_cost_withdrawal = :Var_OM_Cost_Charge_p_tonne,
        efficiency_withdrawal = :H2Stor_eff_charge,
        efficiency_injection = :H2Stor_eff_discharge,
        storage_loss_percentage = :H2Stor_self_discharge_rate_p_hour,
        min_storage_level = :H2Stor_min_level,
    )
end
