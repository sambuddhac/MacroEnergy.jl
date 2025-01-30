using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using YAML
using Gurobi

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

system = Macro.load_system(case_path)

model = Macro.generate_model(system)

Macro.set_optimizer(model, Gurobi.Optimizer);

Macro.set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)

Macro.optimize!(model)

g = system.assets[35].gas_storage;
charge_edge = system.assets[35].charge_edge;
discharge_edge = system.assets[35].discharge_edge;
storage_lvl = Macro.value.(Macro.storage_level(g).data)
storage_init = Macro.value.(Macro.storage_initial(g))
storage_cap = Macro.value.(Macro.capacity_storage(g))
storage_charge = Macro.value.(Macro.flow(charge_edge))
storage_discharge = Macro.value.(Macro.flow(discharge_edge))

full_storage_lvl = zeros(168*365)
MODELED_SUBPERIODS = 1:365
period_map = system.time_data[:Electricity].period_map
rep_periods = system.time_data[:Electricity].subperiod_indices
for n in MODELED_SUBPERIODS
    subperiod_hours = collect((n-1)*168 + 1: n*168)
    rep_subperiod_hours = collect(Macro.subperiods(g)[findfirst(Macro.subperiod_indices(g).==period_map[n])])
    full_storage_lvl[subperiod_hours[1]] = storage_init[n] + storage_charge[rep_subperiod_hours[1]] - storage_discharge[rep_subperiod_hours[1]]
    for i in 2:168
        full_storage_lvl[subperiod_hours[i]] = full_storage_lvl[subperiod_hours[i-1]] + storage_charge[rep_subperiod_hours[i]] - storage_discharge[rep_subperiod_hours[i]]
    end
end

@show number_of_violations = length(findall(full_storage_lvl .> storage_cap))

full_storage_lvl_rep = reduce(vcat,[full_storage_lvl[(p-1)*168 + 1 : p*168] for p in rep_periods])
@show maximum(abs.(storage_lvl - full_storage_lvl_rep))

println("")