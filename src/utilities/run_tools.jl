function run_case(case_path::AbstractString=@__DIR__; optimizer::DataType=HiGHS.Optimizer, lazy_load::Bool=true)
    println("###### ###### ######")
    println("Running case at $(case_path)")

    system = Macro.load_system(case_path; lazy_load=lazy_load)

    model = Macro.generate_model(system)

    Macro.set_optimizer(model, optimizer);

    Macro.set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)

    scale_constraints!(model)

    Macro.optimize!(model)

    capacity_results = Macro.get_optimal_asset_capacity(system)

    results_dir = joinpath(case_path, "results")
    mkpath(results_dir)
    Macro.write_csv(joinpath(results_dir, "capacity.csv"), capacity_results)

    return system, model
end