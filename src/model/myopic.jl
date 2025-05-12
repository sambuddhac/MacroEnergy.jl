struct MyopicResults
    models::Vector{Model}
end

function run_myopic_iteration!(case::Case, opt::Optimizer)
    periods = case.periods
    number_of_case = length(periods)

    models = Vector{Model}(undef, number_of_case)
    for (period_idx,system) in enumerate(periods)
        @info(" -- Generating model for period $(period_idx)")
        model = Model()

        @variable(model, vREF == 1)

        model[:eFixedCost] = AffExpr(0.0)

        model[:eVariableCost] = AffExpr(0.0)

        @info(" -- Adding linking variables")
        add_linking_variables!(system, model) 

        @info(" -- Defining available capacity")
        define_available_capacity!(system, model)

        @info(" -- Generating planning model")
        planning_model!(system, model)

        @info(" -- Generating operational model")
        operation_model!(system, model)

        @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system.assets, model)

        set_optimizer(model, opt)

        scale_constraints!(system, model)

        optimize!(model)

        if period_idx < number_of_case
            @info(" -- Final capacity in period $(period_idx) is being carried over to period $(period_idx+1)")
            carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)
        end

        models[period_idx] = model
    end

    return models
end