function create_nodes_from_dolphyn(
    dolphyn_inputs::Dict,
    commodity::Type{Electricity},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}}
)
    # read number of nodes and demand from dolphyn inputs
    n_nodes = dolphyn_inputs["Z"]
    demand = dolphyn_inputs["pD"]
    max_nsd = dolphyn_inputs["pMax_D_Curtail"];
    price_nsd = dolphyn_inputs["pC_D_Curtail"];
    # select only the time interval of interest
    demand = demand[first(time_interval):last(time_interval), :]

    # create nodes
    nodes = Vector{Node{Electricity}}()
    for i in 1:n_nodes
        node = Node{Electricity}(;
            id = Symbol("E_node_", i),
            demand = demand[:, i],
            time_interval = time_interval,
            subperiods = subperiods,
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
    subperiods::Vector{StepRange{Int64,Int64}}
)
   
    # read number of nodes and demand from dolphyn inputs
    n_nodes = dolphyn_inputs["Z"]
      
    # create nodes
    nodes = Vector{SourceNode{NaturalGas}}()

    for i in 1:n_nodes
        node = SourceNode{NaturalGas}(;
        id = Symbol("NG_node_", i),
        time_interval = time_interval,
        subperiods = subperiods
        )
        push!(nodes, node)
    end

    return nodes
end


function create_nodes_from_dolphyn(
    dolphyn_inputs::Dict,
    commodity::Type{CO2},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}}
)
        
    # create nodes
    nodes = [SinkNode{CO2}(;
        id = Symbol("CO2_node_", 1),
        time_interval = time_interval,
        subperiods = subperiods
        )]

    return nodes
end


function create_nodes_from_dolphyn(
    dolphyn_inputs::Dict,
    commodity::Type{Hydrogen},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}}
)
    # read number of nodes and demand from dolphyn inputs
    n_nodes = dolphyn_inputs["Z"]
    demand = dolphyn_inputs["H2_D"]
    max_nsd = dolphyn_inputs["pMax_H2_D_Curtail"];
    price_nsd = dolphyn_inputs["pC_H2_D_Curtail"];
    # select only the time interval of interest
    demand = demand[first(time_interval):last(time_interval), :]

    # create nodes
    nodes = Vector{Node{Hydrogen}}()
    for i in 1:n_nodes
        node = Node{Hydrogen}(;
            id = Symbol("H2_node_", i),
            demand = demand[:, i],
            time_interval = time_interval,
            subperiods = subperiods,
            max_nsd = max_nsd,
            price_nsd = price_nsd,
        )
        push!(nodes, node)
    end
    return nodes
end

function create_networks_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes::Vector{Node{Electricity}},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}}
)

    number_of_edges = dolphyn_inputs["L"];
    network = Vector{Edge{Electricity}}()
    for i in 1:number_of_edges

        edge = Edge{Electricity}(
        time_interval = time_interval,
        subperiods = subperiods,
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
    nodes::Vector{Node{Electricity}},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # resources available in macro
    macro_resource_types = (
        :solar_photovoltaic,
        :onshore_wind_turbine,
        :offshore_wind_turbine,
        # :conventional_hydroelectric,
        # :small_hydroelectric,
    )
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfGen"]
    # get map from dolphyn columns to macro attributes
    all_attrs = dolphyn_cols_to_macro_attrs(Electricity)
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

    resources = Vector{Resource{Electricity}}()
    # create resource
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        resource_type = Symbol(dfGen.Resource_Type[dfGen.Resource.==string(row.id)][1]);
        if resource_type in macro_resource_types
            node = nodes[zones[i]]  # select the correct node
            resource =  Resource{Electricity}(;
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
    nodes::Vector{SourceNode{NaturalGas}},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    dfGen = dolphyn_inputs["dfGen"];
    fuel_costs = dolphyn_inputs["fuel_costs"];
    
    resources = Vector{Resource{NaturalGas}}()

    for n in 1:dolphyn_inputs["Z"]
        gen_at_node = dfGen[dfGen.Zone.==n,:];

        i = findfirst(occursin.("natural_gas",gen_at_node.Resource));

        push!(resources , Resource{NaturalGas}(;
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

function create_resources_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes::Vector{SinkNode{CO2}},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    
    resources = [Sink{CO2}(;
        node = nodes[1],
        id = :CO2_sink,
        time_interval = time_interval,
        subperiods = subperiods,
        )]
          
    return resources
end

function create_storage_from_dolphyn(
    dolphyn_inputs::Dict,
    nodes::Vector{Node{Hydrogen}},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfH2Gen"]

    # get map from dolphyn columns to macro attributes
    all_attrs = dolphyn_cols_to_macro_attrs(Hydrogen)
    # select only the attributes that are part of a symmetric storage struct
    syms_attr = intersect(propertynames(all_attrs), union(fieldnames(SymmetricStorage),fieldnames(AsymmetricStorage)))

    # swap keys and values
    all_attrs = Dict(all_attrs[key] => key for key in syms_attr)

    # select only the columns of interest
    data = rename(dfGen, pairs(all_attrs))[:, syms_attr]
    data[!, :id] = Symbol.(data[!, :id])
    data[!,:can_expand] = dfGen[!,:New_Build].==1;
    data[!,:can_retire] = dfGen[!,:New_Build].>=0;

    sym_storage = Vector{SymmetricStorage{Hydrogen}}()
    asym_storage = Vector{AsymmetricStorage{Hydrogen}}()
    # create storage
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        node = nodes[zones[i]]  # select the correct node              
        # Create an AsymmetricStorage and push it to asym_storage
        dfGen[i, :H2_STOR] == 1 && push!(
                asym_storage,
                AsymmetricStorage{Hydrogen}(;
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
    nodes::Vector{Node{Electricity}},
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)
    # read dolphyn inputs
    dfGen = dolphyn_inputs["dfGen"]

    # get map from dolphyn columns to macro attributes
    all_attrs = dolphyn_cols_to_macro_attrs(Electricity)
    # select only the attributes that are part of a symmetric storage struct
    syms_attr = intersect(propertynames(all_attrs), union(fieldnames(SymmetricStorage),fieldnames(AsymmetricStorage)))

    # swap keys and values
    all_attrs = Dict(all_attrs[key] => key for key in syms_attr)

    # select only the columns of interest
    data = rename(dfGen, pairs(all_attrs))[:, syms_attr]
    data[!, :id] = Symbol.(data[!, :id])
    data[!,:can_expand] = dfGen[!,:New_Build].==1;
    data[!,:can_retire] = dfGen[!,:New_Build].>=0;

    sym_storage = Vector{SymmetricStorage{Electricity}}()
    asym_storage = Vector{AsymmetricStorage{Electricity}}()
    # create storage
    zones = dfGen.Zone
    for (i, row) in enumerate(eachrow(data))
        node = nodes[zones[i]]  # select the correct node
        # if storage is symmetric, create a SymmetricStorage and push it to sym_storage
        dfGen[i, :STOR] == 1 && push!(
                sym_storage,
                SymmetricStorage{Electricity}(;
                node = node,
                time_interval = time_interval,
                subperiods = subperiods,
                row...,
                ))
                
        # if storage is asymmetric, create an AsymmetricStorage and push it to asym_storage
        dfGen[i, :STOR] == 2 && push!(
                asym_storage,
                AsymmetricStorage{Electricity}(;
                node = node,
                time_interval = time_interval,
                subperiods = subperiods,
                row...,
                ))
    end
    return Storage(sym_storage, asym_storage)
end

function create_transformations_from_dolphyn(
    transform_type::Type{NaturalGasPower},
    dolphyn_inputs::Dict, 
    node_d::Dict, 
    time_interval_commodity_map::Dict,
    subperiods_commodity_map::Dict)

    dfGen = dolphyn_inputs["dfGen"]
    #dfH2Gen = dolphyn_inputs["dfH2Gen"]
    #dfH2G2P = dolphyn_inputs["dfH2G2P"]

    transformations = Vector{Transformation{NaturalGasPower}}()  

    for i in 1:size(dfGen,1)

        if occursin("natural_gas",dfGen.Resource[i])
            electricity_node = node_d[Electricity][dfGen.Zone[i]];
            natural_gas_node = node_d[NaturalGas][dfGen.Zone[i]];   
            co2_node = node_d[CO2][1];

            transformation = Transformation{NaturalGasPower}(;
                id = Symbol(dfGen.Resource[i]),
                time_interval = time_interval_commodity_map[Electricity],
                number_of_stoichiometry_balances = 2,
                )
            
            push!(transformation.TEdges,TEdge{Electricity}(;
            id = Symbol(dfGen.Resource[i]*"_E"),
            node = electricity_node,
            transformation = transformation,
            direction = :output,
            has_planning_variables = true,
            can_expand = dfGen.New_Build[i]==1,
            can_retire = dfGen.New_Build[i]>=0,
            capacity_size = dfGen.Cap_Size[i],
            time_interval = time_interval_commodity_map[Electricity],
            subperiods = subperiods_commodity_map[Electricity],
            st_coeff = [dfGen.Heat_Rate_MMBTU_per_MWh[i],0.0],
            min_capacity = dfGen.Min_Cap_MW[i],
            max_capacity = dfGen.Max_Cap_MW[i],
            existing_capacity = dfGen.Existing_Cap_MW[i],
            investment_cost = dfGen.Inv_Cost_per_MWyr[i],
            fixed_om_cost = dfGen.Fixed_OM_Cost_per_MWyr[i],
            variable_om_cost = dfGen.Var_OM_Cost_per_MWh[i],
            ##### Ignore UC for now
            ######start_cost = dfGen.Start_Cost_per_MW[i],
            ######ucommit = false,
            ramp_up_percentage = dfGen.Ramp_Up_Percentage[i],
            ramp_down_percentage = dfGen.Ramp_Dn_Percentage[i],
            up_time = dfGen.Up_Time[i],
            down_time = dfGen.Down_Time[i],
            min_flow = dfGen.Min_Power[i],
            constraints = [CapacityConstraint()]
            ))

            push!(transformation.TEdges,TEdge{NaturalGas}(;
            id = Symbol(dfGen.Resource[i]*"_NG"),
            node = natural_gas_node,
            transformation = transformation,
            direction = :input,
            has_planning_variables = false,
            time_interval = time_interval_commodity_map[NaturalGas],
            subperiods = subperiods_commodity_map[NaturalGas],
            st_coeff = [1.0,dolphyn_inputs["fuel_CO2"][dfGen.Fuel[i]]]
            ))
            
            push!(transformation.TEdges,TEdge{CO2}(;
            id = Symbol(dfGen.Resource[i]*"_CO2"),
            node = co2_node,
            transformation = transformation,
            direction = :output,
            has_planning_variables = false,
            time_interval = time_interval_commodity_map[CO2],
            subperiods = subperiods_commodity_map[CO2],
            st_coeff = [0.0,1.0]
            ))

            push!(transformations,transformation)

        end

    end

    return transformations

end

function create_transformations_from_dolphyn(
    transform_type::Type{NaturalGasHydrogen},
    dolphyn_inputs::Dict, 
    node_d::Dict, 
    time_interval_commodity_map::Dict,
    subperiods_commodity_map::Dict)

    dfH2Gen = dolphyn_inputs["dfH2Gen"]

    transformations = Vector{Transformation{NaturalGasHydrogen}}()  

    for i in 1:size(dfH2Gen,1)

        if occursin("Large_SMR",dfH2Gen.H2_Resource[i])

            transformation = Transformation{NaturalGasHydrogen}(;
                id = Symbol(dfH2Gen.H2_Resource[i]),
                time_interval = time_interval_commodity_map[Hydrogen],
                number_of_stoichiometry_balances = 2,
                )
            
            push!(transformation.TEdges,TEdge{Hydrogen}(;
            id = Symbol(dfH2Gen.H2_Resource[i]*"_H2"),
            node = node_d[Hydrogen][dfH2Gen.Zone[i]],
            transformation = transformation,
            direction = :output,
            has_planning_variables = true,
            can_expand = dfH2Gen.New_Build[i]==1,
            can_retire = dfH2Gen.New_Build[i]>=0,
            capacity_size = dfH2Gen.Cap_Size_tonne_p_hr[i],
            time_interval = time_interval_commodity_map[Hydrogen],
            subperiods = subperiods_commodity_map[Hydrogen],
            st_coeff = [dfH2Gen.etaFuel_MMBtu_p_tonne[i],0.0],
            min_capacity = dfH2Gen.Min_Cap_tonne_p_hr[i],
            max_capacity = dfH2Gen.Max_Cap_tonne_p_hr[i],
            existing_capacity = dfH2Gen.Existing_Cap_tonne_p_hr[i],
            investment_cost = dfH2Gen.Inv_Cost_p_tonne_p_hr_yr[i],
            fixed_om_cost = dfH2Gen.Fixed_OM_Cost_p_tonne_p_hr_yr[i],
            variable_om_cost = dfH2Gen.Var_OM_Cost_p_tonne[i],
            ##### Ignore UC for now
            ######start_cost = dfGen.Start_Cost_per_MW[i],
            ######ucommit = false,
            ramp_up_percentage = dfH2Gen.Ramp_Up_Percentage[i],
            ramp_down_percentage = dfH2Gen.Ramp_Down_Percentage[i],
            up_time = dfH2Gen.Up_Time[i],
            down_time = dfH2Gen.Down_Time[i],
            min_flow = dfH2Gen.H2Gen_min_output[i],
            constraints = [CapacityConstraint()]
            ))

            push!(transformation.TEdges,TEdge{NaturalGas}(;
            id = Symbol(dfH2Gen.H2_Resource[i]*"_NG"),
            node = node_d[NaturalGas][dfH2Gen.Zone[i]],
            transformation = transformation,
            direction = :input,
            has_planning_variables = false,
            time_interval = time_interval_commodity_map[NaturalGas],
            subperiods = subperiods_commodity_map[NaturalGas],
            st_coeff = [1.0,dolphyn_inputs["fuel_CO2"][dfH2Gen.Fuel[i]]]
            ))
            
            push!(transformation.TEdges,TEdge{CO2}(;
            id = Symbol(dfH2Gen.H2_Resource[i]*"_CO2"),
            node = node_d[CO2][1],
            transformation = transformation,
            direction = :output,
            has_planning_variables = false,
            time_interval = time_interval_commodity_map[CO2],
            subperiods = subperiods_commodity_map[CO2],
            st_coeff = [0.0,1.0]
            ))

            push!(transformations,transformation)

        end

    end

    return transformations

end


function create_transformations_from_dolphyn(
    transform_type::Type{Electrolyzer},
    dolphyn_inputs::Dict, 
    node_d::Dict, 
    time_interval_commodity_map::Dict,
    subperiods_commodity_map::Dict)

    dfH2Gen = dolphyn_inputs["dfH2Gen"]

    transformations = Vector{Transformation{Electrolyzer}}()  

    for i in 1:size(dfH2Gen,1)

        if occursin("Electrolyzer",dfH2Gen.H2_Resource[i])

            transformation = Transformation{Electrolyzer}(;
                id = Symbol(dfH2Gen.H2_Resource[i]),
                time_interval = time_interval_commodity_map[Electricity],
                number_of_stoichiometry_balances = 1,
                )
            
            push!(transformation.TEdges,TEdge{Hydrogen}(;
            id = Symbol(dfH2Gen.H2_Resource[i]*"_H2"),
            node = node_d[Hydrogen][dfH2Gen.Zone[i]],
            transformation = transformation,
            direction = :output,
            has_planning_variables = true,
            can_expand = dfH2Gen.New_Build[i]==1,
            can_retire = dfH2Gen.New_Build[i]>=0,
            capacity_size = dfH2Gen.Cap_Size_tonne_p_hr[i],
            time_interval = time_interval_commodity_map[Hydrogen],
            subperiods = subperiods_commodity_map[Hydrogen],
            st_coeff = [dfH2Gen.etaP2G_MWh_p_tonne[i]],
            min_capacity = dfH2Gen.Min_Cap_tonne_p_hr[i],
            max_capacity = dfH2Gen.Max_Cap_tonne_p_hr[i],
            existing_capacity = dfH2Gen.Existing_Cap_tonne_p_hr[i],
            investment_cost = dfH2Gen.Inv_Cost_p_tonne_p_hr_yr[i],
            fixed_om_cost = dfH2Gen.Fixed_OM_Cost_p_tonne_p_hr_yr[i],
            variable_om_cost = dfH2Gen.Var_OM_Cost_p_tonne[i],
            ##### Ignore UC for now
            ######start_cost = dfGen.Start_Cost_per_MW[i],
            ######ucommit = false,
            ramp_up_percentage = dfH2Gen.Ramp_Up_Percentage[i],
            ramp_down_percentage = dfH2Gen.Ramp_Down_Percentage[i],
            up_time = dfH2Gen.Up_Time[i],
            down_time = dfH2Gen.Down_Time[i],
            min_flow = dfH2Gen.H2Gen_min_output[i],
            constraints = [CapacityConstraint()]
            ))

            push!(transformation.TEdges,TEdge{Electricity}(;
            id = Symbol(dfH2Gen.H2_Resource[i]*"_E"),
            node = node_d[Electricity][dfH2Gen.Zone[i]],
            transformation = transformation,
            direction = :input,
            has_planning_variables = false,
            time_interval = time_interval_commodity_map[Electricity],
            subperiods = subperiods_commodity_map[Electricity],
            st_coeff = [1.0]
            ))
            
            push!(transformations,transformation)

        end

    end

    return transformations

end

function create_transformations_from_dolphyn(
    transform_type::Type{FuelCell},
    dolphyn_inputs::Dict, 
    node_d::Dict, 
    time_interval_commodity_map::Dict,
    subperiods_commodity_map::Dict)

    dfH2G2P = dolphyn_inputs["dfH2G2P"]

    transformations = Vector{Transformation{NaturalGasPower}}()  

    for i in 1:size(dfH2G2P,1)

        if occursin("G2P",dfH2G2P.H2_Resource[i])

            transformation = Transformation{NaturalGasPower}(;
                id = Symbol(dfH2G2P.H2_Resource[i]),
                time_interval = time_interval_commodity_map[Electricity],
                number_of_stoichiometry_balances = 1,
                )
            
            push!(transformation.TEdges,TEdge{Electricity}(;
            id = Symbol(dfH2G2P.H2_Resource[i]*"_E"),
            node = node_d[Electricity][dfH2G2P.Zone[i]],
            transformation = transformation,
            direction = :output,
            has_planning_variables = true,
            can_expand = dfH2G2P.New_Build[i]==1,
            can_retire = dfH2G2P.New_Build[i]>=0,
            capacity_size = dfH2G2P.Cap_Size_MW[i],
            time_interval = time_interval_commodity_map[Electricity],
            subperiods = subperiods_commodity_map[Electricity],
            st_coeff = [1.0],
            min_capacity = dfH2G2P.Min_Cap_MW[i],
            max_capacity = dfH2G2P.Max_Cap_MW[i],
            existing_capacity = dfH2G2P.Existing_Cap_MW[i],
            investment_cost = dfH2G2P.Inv_Cost_p_MW_p_yr[i],
            fixed_om_cost = dfH2G2P.Fixed_OM_p_MW_yr[i],
            variable_om_cost = dfH2G2P.Var_OM_Cost_p_MWh[i],
            ##### Ignore UC for now
            ######start_cost = dfGen.Start_Cost_per_MW[i],
            ######ucommit = false,
            ramp_up_percentage = dfH2G2P.Ramp_Up_Percentage[i],
            ramp_down_percentage = dfH2G2P.Ramp_Down_Percentage[i],
            up_time = dfH2G2P.Up_Time[i],
            down_time = dfH2G2P.Down_Time[i],
            min_flow = dfH2G2P.G2P_min_output[i],
            constraints = [CapacityConstraint()]
            ))

            push!(transformation.TEdges,TEdge{Hydrogen}(;
            id = Symbol(dfH2G2P.H2_Resource[i]*"_H2"),
            node = node_d[Hydrogen][dfH2G2P.Zone[i]],
            transformation = transformation,
            direction = :input,
            has_planning_variables = false,
            time_interval = time_interval_commodity_map[Hydrogen],
            subperiods = subperiods_commodity_map[Hydrogen],
            st_coeff = [dfH2G2P.etaG2P_MWh_p_tonne[i]]
            ))
            
            push!(transformations,transformation)

        end

    end

    return transformations

end



# NOTE 2: TODO: remove double renaming of columns
function dolphyn_to_macro(dolphyn_inputs_original_units::Dict,settings_path::String)

    macro_settings = configure_settings(joinpath(settings_path, "macro_settings.yml"))

    dolphyn_inputs = apply_unit_conversion(dolphyn_inputs_original_units)

    # Data structures to store input data
    node_d = Dict()
    network_d = Dict()
    resource_d = Dict()
    storage_d = Dict()
    transformation_d = Dict()

    macro_settings = (; macro_settings..., PeriodLength=dolphyn_inputs["T"])

    time_interval_commodity_map = Dict();
    subperiods_commodity_map = Dict();

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

        time_interval_commodity_map[commodity] = time_interval;

        subperiods_commodity_map[commodity] = subperiods;

        # load nodes
        nodes = create_nodes_from_dolphyn(dolphyn_inputs, commodity, time_interval,subperiods)
        node_d[commodity] = nodes

        # load networks
        if commodity==Hydrogen
            # Do nothing. For now, we ignore hydrogen pipelines or other forms of H2 transportation.
        elseif commodity==NaturalGas
            # Do nothing. For now, we ignore natural gas pipelines or other forms of NG transportation.
        elseif commodity==CO2
            # Do nothing. For now, we ignore CO2 pipelines or other forms of CO2 transportation.
        else
            network_d[commodity] =
                create_networks_from_dolphyn(dolphyn_inputs, nodes, time_interval,subperiods)
        end

        # load resources 
        if commodity==Hydrogen
            # Do nothing. Dolphyn does not model any hydrogen resource (hydrogen is only produced from either electricity or natural gas)
        else
           resource_d[commodity] = create_resources_from_dolphyn(
                dolphyn_inputs,
                nodes,
                time_interval,
                subperiods,
            )
        end

        # load storage
        if commodity == NaturalGas
            # Do nothing. For now, we ignore Natural Gas storage.
        elseif commodity == CO2
            # Do nothing. For now, we ignore CO2 storage.
        else
            storage_d[commodity] = create_storage_from_dolphyn(
            dolphyn_inputs,
            nodes,
            time_interval,
            subperiods,
            )
        end

    end

    dolphyn_transformation_types = [NaturalGasPower, 
                                    NaturalGasHydrogen, 
                                    Electrolyzer, 
                                    FuelCell]

    for tt in dolphyn_transformation_types

        transformation_d[tt] = create_transformations_from_dolphyn(tt,dolphyn_inputs,node_d, time_interval_commodity_map,subperiods_commodity_map);

    end
    
    @info "Dolphyn data successfully read in into MACRO"

    return InputData(macro_settings, node_d, network_d, resource_d, storage_d,transformation_d), macro_settings
end

function dolphyn_cols_to_macro_attrs(c::Type{Electricity})
    return (
        id = :Resource,
        capacity_size = :Cap_Size,
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
        capacity_size = :Cap_Size_tonne_p_hr,
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


function apply_unit_conversion(inputs_0::Dict)
    # Apply unit conversions to all inputs
    # NOTE: this function is not complete. It only converts the inputs that are currently used in MACRO.

    inputs = deepcopy(inputs_0);

    H2_MWh = 33.33 # MWh per tonne of H2
    NG_MWh = 0.29307107 # MWh per MMBTU of NG

    #### Hydrogen
    inputs["H2_D"] = H2_MWh*inputs["H2_D"]

    columns_p_tonne = [:etaP2G_MWh_p_tonne,
    :etaFuel_MMBtu_p_tonne,
    :Inv_Cost_p_tonne_p_hr_yr,
    :Inv_Cost_Energy_p_tonne_yr,
    :Inv_Cost_Charge_p_tonne_p_hr_yr,
    :Fixed_OM_Cost_p_tonne_p_hr_yr,
    :Fixed_OM_Cost_Energy_p_tonne_yr,
    :Fixed_OM_Cost_Charge_p_tonne_p_hr_yr,
    :Var_OM_Cost_p_tonne,
    :Var_OM_Cost_Charge_p_tonne,
    :Start_Cost_per_tonne_p_hr,
    :CO2_per_tonne]
    
    columns_tonne = [:Max_Cap_tonne_p_hr,
    :Min_Cap_tonne_p_hr,
    :Max_Charge_Cap_tonne_p_hr,
    :Min_Charge_Cap_tonne_p_hr,
    :Max_Energy_Cap_tonne,
    :Min_Energy_Cap_tonne,
    :Existing_Cap_tonne_p_hr,
    :Existing_Charge_Cap_tonne_p_hr,
    :Existing_Energy_Cap_tonne,
    :Cap_Size_tonne_p_hr,
    ]

    inputs["dfH2Gen"][!,columns_p_tonne] = Matrix(inputs["dfH2Gen"][!,columns_p_tonne])./H2_MWh

    inputs["dfH2Gen"][!,columns_tonne] = Matrix(inputs["dfH2Gen"][!,columns_tonne]).*H2_MWh;
    
    inputs["dfH2G2P"][!,:etaG2P_MWh_p_tonne] = inputs["dfH2G2P"][!,:etaG2P_MWh_p_tonne]###### I think this does not need to be converted (it's a unitless percentage), check with Jesse and Dasun. Otherwise, divide by H2_MWh;
    
    #### Natural Gas
    for fc in keys(inputs["fuel_costs"])
        inputs["fuel_costs"][fc] = inputs["fuel_costs"][fc]./H2_MWh
    end

    inputs["dfH2Gen"][!,:etaFuel_MMBtu_p_tonne] = inputs["dfH2Gen"][!,:etaFuel_MMBtu_p_tonne].*NG_MWh;
    inputs["dfGen"][!,:Heat_Rate_MMBTU_per_MWh] = inputs["dfGen"][!,:Heat_Rate_MMBTU_per_MWh].*NG_MWh;
    inputs["dfGen"][!,:Start_Fuel_MMBTU_per_MW] = inputs["dfGen"][!,:Start_Fuel_MMBTU_per_MW].*NG_MWh;
 
    ##### CO2 emissions
    for fc in keys(inputs["fuel_CO2"])
        inputs["fuel_CO2"][fc] = inputs["fuel_CO2"][fc]./NG_MWh
    end

    return inputs

end