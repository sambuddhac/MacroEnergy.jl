using Pkg
Pkg.activate(dirname(@__DIR__))

using Revise
using Macro
using Gurobi
using CSV
using DataFrames
using YAML

H2_MWh = 33.33 # MWh per tonne of H2
NG_MWh = 0.29307107 # MWh per MMBTU of NG
namedtuple(d::Dict) = (; (Symbol(k) => v for (k, v) in d)...)

case_path = pwd()*"/ExampleSystems/three_zones_genx/";

df = CSV.read(case_path*"system/Demand_data.csv",DataFrame);
genx_settings = namedtuple(YAML.load_file(case_path*"settings/genx_settings.yml"));

T = df[1,:Rep_Periods]*df[1,:Timesteps_per_Rep_Period];
macro_settings = (Commodities = Dict(Electricity=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period]),
                                    Hydrogen=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period]),
                                    NaturalGas=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period]),
                                    CO2=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period])),
                PeriodLength = T,
                NumberOfPeriods=1);

                
hours_per_timestep(c) = macro_settings.Commodities[c][:HoursPerTimeStep];
hours_per_subperiod(c) = macro_settings.Commodities[c][:HoursPerSubperiod]
time_interval(c)= 1:hours_per_timestep(c):macro_settings.NumberOfPeriods*macro_settings.PeriodLength

subperiods(c) = collect(Iterators.partition(time_interval(c), Int(hours_per_subperiod(c) / hours_per_timestep(c))))

number_of_electricity_zones = length(names(df)[findfirst(names(df).=="Time_Index")+1:end]);

e_nodes = Vector{Node{Electricity}}(undef, number_of_electricity_zones)
for i in 1:number_of_electricity_zones
    e_nodes[i] = Node{Electricity}(;
        id = Symbol("E_node_$i"),
        demand = df[!,Symbol("Demand_MW_z$i")],
        time_interval = time_interval(Electricity),
        subperiods = subperiods(Electricity),
        max_nsd = Float64.(df[.!ismissing.(df[!,:Max_Demand_Curtailment]),:Max_Demand_Curtailment]),
        price_nsd = Float64.(df[.!ismissing.(df[!,:Cost_of_Demand_Curtailment_per_MW]),:Cost_of_Demand_Curtailment_per_MW])*df[1,:Voll],
        constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint(),Macro.MaxNonServedDemandPerSegmentConstraint()]
    )
end

df = CSV.read(case_path*"system/Network.csv",DataFrame);
number_of_electricity_lines = maximum(df[.!ismissing.(df[!,:Network_Lines]),:Network_Lines]);
e_edges = Vector{Edge{Electricity}}(undef,number_of_electricity_lines)
for i in 1:number_of_electricity_lines
    e_edges[i] = Edge{Electricity}(;
    time_interval=time_interval(Electricity),
    subperiods=subperiods(Electricity),
    start_node = e_nodes[df[i,:Start_Zone]],
    end_node = e_nodes[df[i,:End_Zone]],
    existing_capacity = df[i,:Line_Max_Flow_MW],
    unidirectional = false,
    max_line_reinforcement = df[i,:Line_Max_Reinforcement_MW],
    line_reinforcement_cost = df[i,:Line_Reinforcement_Cost_per_MWyr],
    can_expand = genx_settings.NetworkExpansion==1,
    distance = df[i,:distance_mile],
    line_loss_fraction = 0.0,
    constraints = [Macro.CapacityConstraint()]
    )
end

df = CSV.read(case_path*"resources/Vre.csv",DataFrame);
df_var = CSV.read(case_path*"system/Generators_variability.csv",DataFrame);

vre = Vector{Transformation{VRE}}(undef, size(df,1))
for r in eachrow(df)
    idx = rownumber(r);
    vre[idx] = Transformation{VRE}(;
    id = Symbol(r.Resource),
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity)
    )

    vre[idx].TEdges[:E] =TEdge{Electricity}(;
    id = :E,
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    node = e_nodes[r.Zone],
    transformation = vre[idx],
    direction = :output,
    has_planning_variables = true,
    can_expand = true,
    can_retire = true,
    capacity_factor = df_var[!,Symbol(r.Resource)],
    existing_capacity = r.Existing_Cap_MW,
    investment_cost = r.Inv_Cost_per_MWyr,
    fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
    variable_om_cost = r.Var_OM_Cost_per_MWh,
    constraints = [Macro.CapacityConstraint()],
    )
end


df = CSV.read(case_path*"resources/Storage.csv",DataFrame);
storage = Vector{Transformation{Storage}}(undef,size(df,1));
for r in eachrow(df)
    idx = rownumber(r);
    storage[idx] = Transformation{Storage}(;
    id = Symbol(r.Resource),
    stoichiometry_balance_names = [:storage],
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    can_expand = true,
    can_retire = true,
    existing_capacity_storage = r.Existing_Cap_MWh,
    investment_cost_storage = r.Inv_Cost_per_MWhyr,
    fixed_om_cost_storage = r.Fixed_OM_Cost_per_MWhyr,
    storage_loss_fraction = r.Self_Disch,
    min_duration = r.Min_Duration,
    max_duration = r.Max_Duration,
    discharge_edge = :discharge,
    charge_edge = :charge,
    constraints = [Macro.StorageCapacityConstraint(),Macro.SymmetricCapacityConstraint(),Macro.StoichiometryBalanceConstraint()],
    )
    storage[idx].TEdges[:discharge] = TEdge{Electricity}(;
    id = :discharge,
    node = e_nodes[r.Zone],
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    transformation = storage[idx],
    direction = :output,
    has_planning_variables = true,
    can_expand = true,
    can_retire = true,
    existing_capacity = r.Existing_Cap_MW,
    investment_cost = r.Inv_Cost_per_MWyr,
    fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
    variable_om_cost = r.Var_OM_Cost_per_MWh,
    st_coeff = Dict(:storage=>1/r.Eff_Down),
    constraints = [Macro.CapacityConstraint()],
    )

    storage[idx].TEdges[:charge] = TEdge{Electricity}(;
    id = :charge,
    node = e_nodes[r.Zone],
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    transformation = storage[idx],
    direction = :input,
    has_planning_variables = false,
    can_expand = false,
    can_retire = false,
    variable_om_cost = r.Var_OM_Cost_per_MWh_In,
    st_coeff = Dict(:storage=>r.Eff_Up),
    )
end

df_fuels = CSV.read(case_path*"system/Fuels_data.csv",DataFrame);
ng_node = Node{NaturalGas}(;
    id = :ng_source,
    time_interval = time_interval(NaturalGas),
    subperiods = subperiods(NaturalGas),
    demand = zeros(length(time_interval(NaturalGas))),   
    #### Note that this node does not have a demand balance because we are modeling exogenous inflow of NG
)

df_co2 = CSV.read(case_path*"policies/CO2_cap.csv",DataFrame);
#### We have as many CO2 nodes as the CO_2_Cap_Zones
co2_cap_zones = names(df_co2)[occursin.("CO_2_Cap_Zone_",names(df_co2))];
electricity_zones_to_co2_cap_zones = Dict{Int64,Vector{Int64}}();
for i in 1:number_of_electricity_zones
    electricity_zones_to_co2_cap_zones[i] = findall(collect(df_co2[i,2+1:2+length(co2_cap_zones)]).==1);
end

co2_nodes = Vector{Node{CO2}}(undef,length(co2_cap_zones))
for i in 1:length(co2_cap_zones)
    co2_nodes[i] = Node{CO2}(;
    id = Symbol("CO2_node_$i"),
    time_interval = time_interval(CO2),
    subperiods = subperiods(CO2),
    demand = zeros(length(time_interval(CO2))),
    rhs_policy = Dict(Macro.CO2CapConstraint => 1e6*df_co2[df_co2[!,Symbol("CO_2_Max_Mtons_$i")].>0,Symbol("CO_2_Max_Mtons_$i")][1]),
    constraints = [Macro.CO2CapConstraint()]
    )
end

df = CSV.read(case_path*"resources/Thermal.csv",DataFrame);
thermal = Vector{Transformation{NaturalGasPower}}(undef,size(df,1));
for r in eachrow(df)
    idx = rownumber(r);
    thermal[idx] = Transformation{NaturalGasPower}(;
    id = Symbol(r.Resource),
    time_interval = time_interval(Electricity),
    stoichiometry_balance_names = [:energy,:emissions],
    constraints = [Macro.StoichiometryBalanceConstraint()]
    )
  
    thermal[idx].TEdges[:E] = TEdgeWithUC{Electricity}(;
    id = :E,
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    node = e_nodes[r.Zone],
    transformation = thermal[idx],
    direction = :output,
    has_planning_variables = true,
    can_expand = true,
    can_retire = true,
    capacity_size = r.Cap_Size,
    st_coeff = Dict(:energy=>r.Heat_Rate_MMBTU_per_MWh*NG_MWh,:emissions=>0.0),
    existing_capacity = r.Existing_Cap_MW,
    investment_cost = r.Inv_Cost_per_MWyr,
    fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
    variable_om_cost =r.Var_OM_Cost_per_MWh,
    ramp_up_fraction = r.Ramp_Up_Percentage,
    ramp_down_fraction = r.Ramp_Dn_Percentage,
    min_flow_fraction = r.Min_Power,
    min_up_time = r.Up_Time,
    min_down_time = r.Down_Time,
    start_cost = r.Start_Cost_per_MW,
    start_fuel = r.Start_Fuel_MMBTU_per_MW*NG_MWh,
    start_fuel_stoichiometry_name = :energy,
    constraints = [Macro.CapacityConstraint(), 
                    Macro.RampingLimitConstraint(),
                    Macro.MinFlowConstraint(),
                    Macro.MinUpTimeConstraint(),
                    Macro.MinDownTimeConstraint()]
    )

    thermal[idx].TEdges[:NG] = TEdge{NaturalGas}(;
    id = :NG,
    time_interval = time_interval(NaturalGas),
    subperiods = subperiods(NaturalGas),
    node = ng_node,
    transformation = thermal[idx],
    direction = :input,
    has_planning_variables = false,
    st_coeff = Dict(:energy=>1.0,:emissions=>df_fuels[1,Symbol(r.Fuel)]/NG_MWh),
    price = df_fuels[2:end,Symbol(r.Fuel)]/NG_MWh,
    )

    for j in electricity_zones_to_co2_cap_zones[r.Zone]
        thermal[idx].TEdges[Symbol("CO2_$j")] = TEdge{CO2}(;
        id = Symbol("CO2_$j"),
        time_interval = time_interval(CO2),
        subperiods = subperiods(CO2),
        node = co2_nodes[j],
        transformation = thermal[idx],
        direction = :output,
        has_planning_variables = false,
        st_coeff = Dict(:energy=>0.0,:emissions=>1.0)
        )
    end

end

system = [e_nodes;ng_node;co2_nodes;e_edges;vre;storage;thermal];
model = Macro.generate_model(system);
Macro.set_optimizer(model,Gurobi.Optimizer);
Macro.optimize!(model)
macro_objval = Macro.objective_value(model)
df_genx_status = CSV.read(case_path*"results/Status.csv",DataFrame);

println("The relative error between Macro and GenX is $(abs(df_genx_status.Objval[1]-macro_objval)/df_genx_status.Objval[1])")

println("The runtime for Macro was $(Macro.solve_time(model))")

println("The runtime for GenX was $(df_genx_status.Solve[1])")