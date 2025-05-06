struct MyopicResults
    models::Vector{Model}
end

function run_myopic_iteration!(stages::Stages, opt::Optimizer)
    systems = stages.systems
    number_of_stages = length(systems)

    models = Vector{Model}(undef, number_of_stages)
    for s in 1:number_of_stages
        system = systems[s];
        @info(" -- Generating model for stage $(s)")
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
        add_age_based_retirements!.(systems[s].assets, model)

        set_optimizer(model, opt)

        scale_constraints!(systems[s], model)

        optimize!(model)

        if s < number_of_stages
            @info(" -- Final capacity in stage $(s) is being carried over to stage $(s+1)")
            carry_over_capacities!(systems[s+1], systems[s], perfect_foresight=false)
        end

        models[s] = model
    end

    return models
end