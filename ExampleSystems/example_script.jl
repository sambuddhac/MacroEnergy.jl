using Pkg
Pkg.activate((dirname(@__DIR__)))

using Revise
using Macro
using Gurobi
using CSV
using DataFrames

T = 10*24;
macro_settings = (Commodities = Dict(Electricity=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24),
                                    Hydrogen=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24),
                                    NaturalGas=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24),
                                    CO2=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24)),
                PeriodLength = T,
                NumberOfPeriods=1);

                
hours_per_timestep(c) = macro_settings.Commodities[c][:HoursPerTimeStep];
hours_per_subperiod(c) = macro_settings.Commodities[c][:HoursPerSubperiod]
time_interval(c)= 1:hours_per_timestep(c):macro_settings.NumberOfPeriods*macro_settings.PeriodLength

subperiods(c) = collect(Iterators.partition(time_interval(c), Int(hours_per_subperiod(c) / hours_per_timestep(c))),)



df = CSV.read(dirname(@__DIR__)*"/tutorials/time_series_data.csv",DataFrame)
electricity_demand = df[1:T,:Electricity_Demand_MW]; # MWh
solar_capacity_factor = df[1:T,:Solar_Capacity_Factor]; # factor between 0 and 1
ng_fuel_price = df[1:T,:NG_Price]/0.29307107; # $/MWh of natural gas

e_node = Node{Electricity}(;
    id = Symbol("E_node"),
    demand = electricity_demand,
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    max_nsd = [0.0],
    price_nsd = [0.0],
    constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
)

solar_pv = Transformation{SolarPV}(;
id = :solar_pv,
time_interval = time_interval(Electricity),
)

solar_pv.TEdges[:E] = TEdge{Electricity}(;
id = :E,
node = e_node,
transformation = solar_pv,
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
capacity_factor = solar_capacity_factor,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
existing_capacity = 0.0,
investment_cost = 85300,
fixed_om_cost = 18760.0,
constraints = [Macro.CapacityConstraint()]
)

battery = Transformation{Storage}(;
id = :battery,
stoichiometry_balance_names = [:storage],
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
can_expand = true,
can_retire = false,
existing_capacity_storage = 0.0,
investment_cost_storage = 22494.0,
fixed_om_cost_storage = 5622,
min_duration = 1,
max_duration = 10,
constraints = [Macro.StorageCapacityConstraint(),Macro.StoichiometryBalanceConstraint()],
discharge_capacity_edge = :E_INJ
)

battery.TEdges[:E_INJ] = TEdge{Electricity}(;
id = :E_INJ,
node = e_node,
transformation = battery,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
existing_capacity = 0.0,
investment_cost = 19584.0,
fixed_om_cost = 4895,
variable_om_cost = 0.15,
st_coeff = Dict(:storage=>1/0.92),
constraints = [Macro.CapacityConstraint()]
)

battery.TEdges[:E_WDW] = TEdge{Electricity}(;
id = :E_WDW,
node = e_node,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
transformation = battery,
direction = :input,
has_planning_variables = false,
can_expand = false,
can_retire = false,
variable_om_cost = 0.15,
st_coeff = Dict(:storage=>0.92),
)

system = [e_node; solar_pv;battery]

model = Macro.Model()
Macro.@variable(model, vREF == 1)
Macro.@expression(model, eFixedCost, 0 * model[:vREF])
Macro.@expression(model, eVariableCost, 0 * model[:vREF])
Macro.add_planning_variables!.(system, Ref(model))
Macro.add_operation_variables!.(system, Ref(model))
Macro.add_all_model_constraints!.(system, Ref(model))


# solar_pv = Resource{Electricity}(;
#     id = :Solar_PV,
#     node = e_node,
#     time_interval = time_interval(Electricity),
#     subperiods = subperiods(Electricity),
#     capacity_factor = solar_capacity_factor,
#     can_expand = true, 
#     can_retire = false,
#     existing_capacity = 0.0,
#     investment_cost = 85300,
#     fixed_om_cost = 18760.0,
#     constraints = [Macro.CapacityConstraint()]
# )

# battery = SymmetricStorage{Electricity}(;
#     id = :battery,
#     node = e_node,
#     time_interval = time_interval(Electricity),
#     subperiods = subperiods(Electricity),
#     can_expand = true,
#     can_retire = false,
#     existing_capacity = 0.0,
#     investment_cost = 19584.0,
#     investment_cost_storage = 22494.0,
#     fixed_om_cost = 4895,
#     fixed_om_cost_storage = 5622,
#     variable_om_cost = 0.15,
#     variable_om_cost_storage = 0.15,
#     efficiency_injection = 0.92,
#     efficiency_withdrawal = 0.92,
#     min_duration = 1,
#     max_duration = 10,
#     constraints = [Macro.CapacityConstraint(),Macro.StorageCapacityConstraint(),Macro.MinStorageDurationConstraint(),Macro.MaxStorageDurationConstraint()]
# )

# ng_node = Node{NaturalGas}(;
#     id = Symbol("NG_node"),
#     time_interval = time_interval(NaturalGas),
#     subperiods = subperiods(NaturalGas),
#     demand = zeros(length(time_interval(NaturalGas))),
#     max_nsd = [0.0],
#     price_nsd = [0.0],
#     constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
# )
# ng_source = Resource{NaturalGas}(;
# id = :NG_Source,
# node = ng_node,
# time_interval = time_interval(NaturalGas),
# subperiods = subperiods(NaturalGas),
# can_expand = false, 
# can_retire = false,
# price = ng_fuel_price,
# existing_capacity = Inf,
# )

# co2_node = Node{CO2}(;
# id = Symbol("CO2_node"),
# time_interval = time_interval(CO2),
# subperiods = subperiods(CO2),
# demand = zeros(length(time_interval(CO2))),
# max_nsd = [0.0],
# price_nsd = [0.0],
# constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
# )

# co2_captured_node = Node{CO2Captured}(;
# id = Symbol("CO2_captured_node"),
# time_interval = time_interval(CO2),
# subperiods = subperiods(CO2),
# demand = zeros(length(time_interval(CO2))),
# max_nsd = [0.0],
# price_nsd = [0.0],
# constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
# )


# ngcc_ccs = Transformation{NaturalGasPowerCCS}(;
# id = :NGCC_CCS,
# time_interval = time_interval(Electricity),
# stoichiometry_balance_names = [:energy,:emissions,:captured_emissions],
# constraints = [Macro.StoichiometryBalanceConstraint()]
# )

# ngcc_ccs.TEdges[:E] = TEdge{Electricity}(;
# id = :E,
# node = e_node,
# transformation = ngcc_ccs,
# direction = :output,
# has_planning_variables = true,
# can_expand = true,
# can_retire = false,
# capacity_size = 250,
# time_interval = time_interval(Electricity),
# subperiods = subperiods(Electricity),
# st_coeff = Dict(:energy=>2.1775180500999998,:emissions=>0.0,:captured_emissions=>0.0),
# existing_capacity = 0.0,
# investment_cost = 66400,
# fixed_om_cost = 12287.0,
# variable_om_cost = 3.65,
# constraints = [CapacityConstraint()]
# )

# ngcc_ccs.TEdges[:NG] = TEdge{NaturalGas}(;
# id =  :NG,
# node = ng_node,
# transformation = ngcc_ccs,
# direction = :input,
# has_planning_variables = false,
# time_interval = time_interval(NaturalGas),
# subperiods = subperiods(NaturalGas),
# st_coeff = Dict(:energy=>1.0,:emissions=>0.181048235160161*(1-0.9),:captured_emissions=>0.181048235160161*0.9)
# )

# ngcc_ccs.TEdges[:CO2] = TEdge{CO2}(;
#     id = :CO2,
#     node = co2_node,
#     transformation = ngcc_ccs,
#     direction = :output,
#     has_planning_variables = false,
#     time_interval = time_interval(CO2),
#     subperiods = subperiods(CO2),
#     st_coeff = Dict(:energy=>0.0,:emissions=>1.0,:captured_emissions=>0.0)
# )

# ngcc_ccs.TEdges[:CO2_Captured] = TEdge{CO2Captured}(;
#     id = :CO2,
#     node = co2_captured_node,
#     transformation = ngcc_ccs,
#     direction = :output,
#     has_planning_variables = false,
#     time_interval = time_interval(CO2),
#     subperiods = subperiods(CO2),
#     st_coeff = Dict(:energy=>0.0,:emissions=>0.0,:captured_emissions=>1.0)
# )

# model = Macro.JuMP.Model();
# Macro.@variable(model,vREF==1) ## Variable used to initialize empty expressions
# Macro.@expression(model, eFixedCost, 0 * model[:vREF]);
# Macro.@expression(model, eVariableCost, 0 * model[:vREF]);
# Macro.add_operation_variables!.(e_node,model)
# Macro.add_operation_variables!(ng_node,model)
# Macro.add_operation_variables!(co2_node,model)
# Macro.add_operation_variables!(co2_captured_node,model)

# Macro.add_planning_variables!(ngcc_ccs,model)

# Macro.add_operation_variables!(ngcc_ccs,model)

# Macro.add_all_model_constraints!(ngcc_ccs, model)