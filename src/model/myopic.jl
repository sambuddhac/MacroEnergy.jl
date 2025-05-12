struct MyopicResults
    models::Vector{Model}
end

function run_myopic_iteration!(case::Case, opt::Optimizer)

    periods = case.periods
    settings = case.settings

    number_of_periods = length(periods)

    fixed_cost = Dict()
    variable_cost = Dict()

    models = Vector{Model}(undef, number_of_periods)
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

        # Express myopic cost in present value from perspective of start of modeling horizon, in consistency with Monolithic version

        fixed_cost[period_idx] = model[:eFixedCost];
	    unregister(model,:eFixedCost)
        
        variable_cost[period_idx] = model[:eVariableCost];
        unregister(model,:eVariableCost)
        

        period_lengths = collect(settings.PeriodLengths)

        discount_rate = settings.DiscountRate
    
        cum_years = [sum(period_lengths[i] for i in 1:s-1; init=0) for s in 1:number_of_periods];
    
        discount_factor = 1 ./ ( (1 + discount_rate) .^ cum_years)
    
        @expression(model, eFixedCostByPeriod, discount_factor * fixed_cost[period_idx])
    
        @expression(model, eFixedCost, eFixedCostByPeriod)
    
        opexmult = [sum([1 / (1 + discount_rate)^(i) for i in 1:period_lengths[s]]) for s in 1:number_of_periods]
    
        @expression(model, eVariableCostByPeriod, discount_factor * opexmult[period_idx] * variable_cost[period_idx])
    
        @expression(model, eVariableCost, eVariableCostByPeriod)

        @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system.assets, model)

        set_optimizer(model, opt)

        scale_constraints!(system, model)

        optimize!(model)

        if period_idx < number_of_periods
            @info(" -- Final capacity in period $(period_idx) is being carried over to period $(period_idx+1)")
            carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)
        end

        models[period_idx] = model
    end

    return models
end