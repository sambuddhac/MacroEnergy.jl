function run_case(case_path::AbstractString=@__DIR__; lazy_load::Bool=true, optimizer::DataType=HiGHS.Optimizer, optimizer_env::Any=missing)
    println("###### ###### ######")
    println("Running case at $(case_path)")

    system = load_system(case_path; lazy_load=lazy_load)

    model = generate_model(system)

    if !ismissing(optimizer_env)
        try 
            set_optimizer(model, () -> optimizer(optimizer_env));
        catch
            error("Error creating optimizer with environment. Check that the environment is valid.")
        end
    else
        set_optimizer(model, optimizer);
    end

    try
        set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)
    catch
        @warn("Error setting optimizer attributes. Check that the optimizer is valid.")
    end

    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    optimize!(model)
    
    ## Output results
    results_dir = joinpath(case_path, "results")
    mkpath(results_dir)
    
    # Capacity results
    write_capacity_results(joinpath(results_dir, "capacity.csv"), system)
    
    # Cost results
    cost_results = get_optimal_costs(system, model)
    write_dataframe(joinpath(results_dir, "costs.csv"), cost_results)

    return system, model
end