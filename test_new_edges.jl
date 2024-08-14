# using Pkg
# Pkg.activate(".")

import Macro as m

using Gurobi

timedata_elec = m.TimeData{m.Electricity}(
time_interval = 1:1:10,
subperiods = [1:10],
subperiod_weights = Dict(1:10 => 1.0)
)

timedata_ng = m.TimeData{m.NaturalGas}(
time_interval = 1:1:10,
subperiods = [1:10],
subperiod_weights = Dict(1:10 => 1.0)
)
timedata_co2 = m.TimeData{m.CO2}(
time_interval = 1:1:10,
subperiods = [1:10],
subperiod_weights = Dict(1:10 => 1.0)
)

elec_node = m.Node{m.Electricity}(;
    id = :elec_node,
    demand = 3*ones(10),
    timedata = timedata_elec,
    max_nsd = [3.0],
    price_nsd = [0.0],
    balance_data = Dict(:demand=>Dict()),
    constraints = [m.BalanceConstraint();m.MaxNonServedDemandConstraint()]
)

solar_pv = m.Transformation(
id = :solar_pv,
timedata = timedata_elec
)

solar_pv_edge = m.Edge{m.Electricity}(
id = :solar,
start_vertex = solar_pv,
end_vertex = elec_node,
timedata = timedata_elec,
unidirectional = true,
has_planning_variables = true,
can_retire = false,
can_expand = true,
capacity_factor = rand(10),
constraints = [m.CapacityConstraint()]
)

ng_node = m.Node{m.NaturalGas}(
    id = :ng_plant,
    timedata = timedata_ng,
)

co2_node = m.Node{m.CO2}(
    id = :co2_node,
    timedata = timedata_co2,
)

ng_plant = m.Transformation(
id = :ng_plant,
timedata = timedata_elec,
balance_data = Dict(:energy=>Dict(:E=>2.1775180500999998,:NG=>1.0,:CO2=>0.0),:emissions=>Dict(:E=>0.0,:NG=>0.181048235160161,:CO2=>1.0)),
constraints = [m.BalanceConstraint()]
)

ng_inflow = m.Edge{m.NaturalGas}(
id = :NG,
start_vertex = ng_node,
end_vertex = ng_plant,
timedata = timedata_ng,
unidirectional = true,
has_planning_variables = false,
price = 3.5*ones(10),
) 

ng_power_out = m.EdgeWithUC{m.Electricity}(
id = :E,
start_vertex = ng_plant,
end_vertex = elec_node,
timedata = timedata_elec,
unidirectional = true,
has_planning_variables = true,
can_retire = true,
can_expand = true,
min_up_time = 7,
min_down_time = 10,
startup_cost = 91,
startup_fuel = 0.58614214,
startup_fuel_balance_id = :energy,
constraints = [m.CapacityConstraint(),m.RampingLimitConstraint(),m.MinUpTimeConstraint(),m.MinDownTimeConstraint()]
) 

ng_co2_out = m.Edge{m.CO2}(
id = :CO2,
start_vertex = ng_plant,
end_vertex = co2_node,
timedata = timedata_co2,
unidirectional = true,
has_planning_variables = false,
) 

battery = m.Storage{m.Electricity}(
    id = :battery,
    timedata = timedata_elec,
    can_retire = true,
    can_expand = true,
    min_duration = 1.0,
    max_duration = 10.0,
    storage_loss_fraction= 0.05,
    balance_data = Dict(:storage=>Dict(:discharge=>1/0.9,:charge=>0.9)),
    constraints = [m.BalanceConstraint(),m.StorageCapacityConstraint(),m.StorageMaxDurationConstraint(),m.StorageMinDurationConstraint(),m.StorageSymmetricCapacityConstraint()]
)

battery_d = m.Edge{m.Electricity}(
    id = :discharge,
    start_vertex = battery,
    end_vertex = elec_node,
    timedata = timedata_elec,
    unidirectional = true,
    has_planning_variables = true,
    can_retire = false,
    can_expand = true,
    constraints = [m.CapacityConstraint(),m.RampingLimitConstraint()]
)
battery_c = m.Edge{m.Electricity}(
    id = :charge,
    start_vertex = elec_node,
    end_vertex = battery,
    timedata = timedata_elec,
    unidirectional = true, 
    has_planning_variables = false,
)

battery.discharge_edge = battery_d;
battery.charge_edge = battery_c;

model = m.Model();

m.@variable(model, vREF == 1)

model[:eFixedCost] = m.AffExpr(0.0)

model[:eVariableCost] = m.AffExpr(0.0)

system = [elec_node;ng_node;co2_node;solar_pv;battery;ng_plant;solar_pv_edge;ng_inflow;ng_power_out;ng_co2_out;battery_c;battery_d]

m.add_planning_variables!.(system,model);

m.add_operation_variables!.(system,model);

m.add_all_model_constraints!.(system,model);

m.set_optimizer(model,Gurobi.Optimizer);

m.optimize!(model)
