using Pkg
Pkg.activate((dirname(@__DIR__)))

using Revise
using Macro
using Gurobi

T = 8760;
macro_settings = (Commodities = Dict(Electricity=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>T),
                                    Hydrogen=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>T),
                                    NaturalGas=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>T),
                                    CO2=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>T)),
                PeriodLength = T);


hours_per_timestep(c) = macro_settings.Commodities[c][:HoursPerTimeStep];
hours_per_subperiod(c) = macro_settings.Commodities[c][:HoursPerSubperiod]
time_interval(c)= 1:hours_per_timestep(c):macro_settings.PeriodLength

subperiods(c) = collect(Iterators.partition(time_interval(c), Int(hours_per_subperiod(c) / hours_per_timestep(c))),)


e_node = Node{Electricity}(;
    id = Symbol("E_node"),
    demand = zeros(length(time_interval(Electricity))),
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    max_nsd = [0.0],
    price_nsd = [50000],
    constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
)

ng_node = Node{NaturalGas}(;
    id = Symbol("NG_node"),
    time_interval = time_interval(NaturalGas),
    subperiods = subperiods(NaturalGas),
    demand = zeros(length(time_interval(NaturalGas))),
    max_nsd = [0.0],
    price_nsd = [0.0],
    constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
)

co2_node = Node{CO2}(;
id = Symbol("CO2_node"),
time_interval = time_interval(CO2),
subperiods = subperiods(CO2),
demand = zeros(length(time_interval(CO2))),
max_nsd = [0.0],
price_nsd = [0.0],
constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
)

co2_captured_node = Node{CO2}(;
id = Symbol("CO2_captured_node"),
time_interval = time_interval(CO2),
subperiods = subperiods(CO2),
demand = zeros(length(time_interval(CO2))),
max_nsd = [0.0],
price_nsd = [0.0],
constraints = [Macro.DemandBalanceConstraint(),Macro.MaxNonServedDemandConstraint()]
)


ngcc_ccs = Transformation{NaturalGasPowerCCS}(;
id = :NGCC_CCS,
time_interval = time_interval(Electricity),
stoichiometry_balance_names = [:energy,:emissions,:captured_emissions],
constraints = [Macro.StoichiometryBalanceConstraint()]
)

ngcc_ccs.TEdges[:E] = TEdge{Electricity}(;
id = :E,
node = e_node,
transformation = ngcc_ccs,
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
capacity_size = 250,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
st_coeff = Dict(:energy=>2.1775180500999998,:emissions=>0.0,:captured_emissions=>0.0),
existing_capacity = 0.0,
investment_cost = 66400,
fixed_om_cost = 12287.0,
variable_om_cost = 3.65,
constraints = [CapacityConstraint()]
)

ngcc_ccs.TEdges[:NG] = TEdge{NaturalGas}(;
id =  :NG,
node = ng_node,
transformation = ngcc_ccs,
direction = :input,
has_planning_variables = false,
time_interval = time_interval(NaturalGas),
subperiods = subperiods(NaturalGas),
st_coeff = Dict(:energy=>1.0,:emissions=>0.181048235160161*(1-0.9),:captured_emissions=>0.181048235160161*0.9)
)

ngcc_ccs.TEdges[:CO2] = TEdge{CO2}(;
    id = :CO2,
    node = co2_node,
    transformation = ngcc_ccs,
    direction = :output,
    has_planning_variables = false,
    time_interval = time_interval(CO2),
    subperiods = subperiods(CO2),
    st_coeff = Dict(:energy=>0.0,:emissions=>1.0,:captured_emissions=>0.0)
)

ngcc_ccs.TEdges[:CO2_Captured] = TEdge{CO2}(;
    id = :CO2,
    node = co2_node,
    transformation = ngcc_ccs,
    direction = :output,
    has_planning_variables = false,
    time_interval = time_interval(CO2),
    subperiods = subperiods(CO2),
    st_coeff = Dict(:energy=>0.0,:emissions=>0.0,:captured_emissions=>1.0)
)

model = Macro.JuMP.Model();
Macro.@variable(model,vREF==1) ## Variable used to initialize empty expressions
Macro.@expression(model, eFixedCost, 0 * model[:vREF]);
Macro.@expression(model, eVariableCost, 0 * model[:vREF]);

Macro.add_operation_variables!(e_node,model)
Macro.add_operation_variables!(ng_node,model)
Macro.add_operation_variables!(co2_node,model)
Macro.add_operation_variables!(co2_captured_node,model)

Macro.add_planning_variables!(ngcc_ccs,model)

Macro.add_operation_variables!(ngcc_ccs,model)

Macro.add_all_model_constraints!(ngcc_ccs, model)