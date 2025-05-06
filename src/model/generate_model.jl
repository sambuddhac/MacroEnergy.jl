function generate_model(system::System)

    @info("Generating model")

    start_time = time();

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

    @info(" -- Model generation complete. It took $(round(time() - start_time, digits=2)) seconds")

    return model

end


function planning_model!(system::System, model::Model)

    planning_model!.(system.locations, Ref(model))

    planning_model!.(system.assets, Ref(model))

    add_constraints_by_type!(system, model, PlanningConstraint)

end


function operation_model!(system::System, model::Model)

    operation_model!.(system.locations, Ref(model))

    operation_model!.(system.assets, Ref(model))

    add_constraints_by_type!(system, model, OperationConstraint)

end

function planning_model!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        planning_model!(getfield(a, t), model)
    end
    return nothing
end

function operation_model!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        operation_model!(getfield(a, t), model)
    end
    return nothing
end

function add_linking_variables!(system::System, model::Model)

    add_linking_variables!.(system.locations, model)

    add_linking_variables!.(system.assets, model)

end

function add_linking_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_linking_variables!(getfield(a, t), model)
    end
end

function define_available_capacity!(system::System, model::Model)

    define_available_capacity!.(system.locations, model)

    define_available_capacity!.(system.assets, model)

end

function define_available_capacity!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        define_available_capacity!(getfield(a, t), model)
    end
end

function generate_model(stages::Stages)
    generate_model(stages, expansion_mode(stages))
end

# Single stage model
function generate_model(stages::Stages, ::SingleStage)
    return generate_model(stages.systems[1])
end

# Multistage model with perfect foresight
function generate_model(stages::Stages, ::PerfectForesight)

    systems = stages.systems
    settings = stages.settings

    @info("Generating multistage model with perfect foresight")

    start_time = time();

    model = Model()

    @variable(model, vREF == 1)

    number_of_stages = length(systems)

    fixed_cost = Dict()
    variable_cost = Dict()

    for s in 1:number_of_stages

        @info(" -- Stage $s")

        model[:eFixedCost] = AffExpr(0.0)
        model[:eVariableCost] = AffExpr(0.0)

        @info(" -- Adding linking variables")
        add_linking_variables!(systems[s], model) 

        @info(" -- Defining available capacity")
        define_available_capacity!(systems[s], model)

        @info(" -- Generating planning model")
        planning_model!(systems[s], model)

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(systems[s].assets, model)

        if s < number_of_stages
            @info(" -- Available capacity in stage $(s) is being carried over to stage $(s+1)")
            carry_over_capacities!(systems[s+1], systems[s])
        end

        @info(" -- Generating operational model")
        operation_model!(systems[s], model)

        fixed_cost[s] = model[:eFixedCost];
	    unregister(model,:eFixedCost)

        variable_cost[s] = model[:eVariableCost];
        unregister(model,:eVariableCost)

    end

    #The settings are the same in all stages, we have a single settings file that gets copied into each system struct
    stage_lengths = collect(settings.StageLengths)

    wacc = settings.WACC

    cum_years = [sum(stage_lengths[i] for i in 1:s-1; init=0) for s in 1:number_of_stages];

    discount_factor = 1 ./ ( (1 + wacc) .^ cum_years)

    @expression(model, eDiscountedFixedCost[s in 1:number_of_stages], discount_factor[s] * fixed_cost[s])

    @expression(model, eFixedCost, sum(eDiscountedFixedCost[s] for s in 1:number_of_stages))

    opexmult = [sum([1 / (1 + wacc)^(i - 1) for i in 1:stage_lengths[s]]) for s in 1:number_of_stages]

    @expression(model, eDiscountedVariableCost[s in 1:number_of_stages], discount_factor[s] * opexmult[s] * variable_cost[s])

    @expression(model, eVariableCost, sum(eDiscountedVariableCost[s] for s in 1:number_of_stages))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    @info(" -- Model generation complete, it took $(time() - start_time) seconds")

    return model
    
end

function add_age_based_retirements!(a::AbstractAsset,model::Model)

    for t in fieldnames(typeof(a))
        y = getfield(a, t)
        if isa(y,AbstractEdge) || isa(y,Storage)
            if y.retirement_stage > 0
                push!(y.constraints, AgeBasedRetirementConstraint())
                add_model_constraint!(y.constraints[end], y, model)
            end
        end
    end

end

#### All new capacity built up to the retirement stage must retire in the current stage
function get_retirement_stage(cur_stage::Int,lifetime::Int,stage_lengths::Vector{Int})

    return maximum(filter(r -> sum(stage_lengths[t] for t in r+1:cur_stage; init=0) >= lifetime,1:cur_stage-1);init=0)

end

function compute_retirement_stage!(system::System, stage_lengths::Vector{Int})
    
    for a in system.assets
        compute_retirement_stage!(a, stage_lengths)
    end

    return nothing
end

function compute_retirement_stage!(a::AbstractAsset, stage_lengths::Vector{Int})

    for t in fieldnames(typeof(a))
        y = getfield(a, t)
        
        if :retirement_stage ∈ Base.fieldnames(typeof(y))
            if can_retire(y)
                y.retirement_stage = get_retirement_stage(stage_index(y),lifetime(y),stage_lengths)
            end
        end
    end

    return nothing
end

function carry_over_capacities!(system::System, system_prev::System; perfect_foresight::Bool = true)

    for a in system.assets
        a_prev_index = findfirst(id.(system_prev.assets).==id(a))
        if isnothing(a_prev_index)
            @info("Skipping asset $(id(a)) as it was not present in the previous stage")
            validate_existing_capacity(a)
        else
            a_prev = system_prev.assets[a_prev_index];
            carry_over_capacities!(a, a_prev ; perfect_foresight)
        end
    end

end

function carry_over_capacities!(a::AbstractAsset, a_prev::AbstractAsset; perfect_foresight::Bool = true)

    for t in fieldnames(typeof(a))
        carry_over_capacities!(getfield(a,t), getfield(a_prev,t); perfect_foresight)
    end

end

function carry_over_capacities!(y::Union{AbstractEdge,AbstractStorage},y_prev::Union{AbstractEdge,AbstractStorage}; perfect_foresight::Bool = true)
    if has_capacity(y_prev)
        
        if perfect_foresight
            y.existing_capacity = capacity(y_prev)
        else
            y.existing_capacity = value(capacity(y_prev))
        end
        
        for prev_stage in keys(new_capacity_track(y_prev))
            if perfect_foresight
                y.new_capacity_track[prev_stage] = new_capacity_track(y_prev,prev_stage)
                y.retired_capacity_track[prev_stage] = retired_capacity_track(y_prev,prev_stage)
            else
                y.new_capacity_track[prev_stage] = value(new_capacity_track(y_prev,prev_stage))
                y.retired_capacity_track[prev_stage] = value(retired_capacity_track(y_prev,prev_stage))
            end
        end
        
    end
end
function carry_over_capacities!(g::Transformation,g_prev::Transformation; perfect_foresight::Bool = true)
    return nothing
end
function carry_over_capacities!(n::Node,n_prev::Node; perfect_foresight::Bool = true)
    return nothing
end


function discount_fixed_costs!(system::System, settings::NamedTuple)
    for a in system.assets
        discount_fixed_costs!(a, settings)
    end
end

function discount_fixed_costs!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        discount_fixed_costs!(getfield(a, t), settings)
    end
end

function discount_fixed_costs!(y::Union{AbstractEdge,AbstractStorage},settings::NamedTuple)
    
    # Number of years of payments that are remaining
    model_years_remaining = sum(settings.StageLengths[stage_index(y):end]; init = 0);
    payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);

    y.investment_cost = investment_cost(y) * sum(1 / (1 + wacc(y))^s for s in 1:payment_years_remaining; init=0);
    
    opexmult = sum([1 / (1 + settings.WACC)^(i - 1) for i in 1:settings.StageLengths[stage_index(y)]])

    y.fixed_om_cost = fixed_om_cost(y) * opexmult

end
function discount_fixed_costs!(g::Transformation,settings::NamedTuple)
    return nothing
end
function discount_fixed_costs!(n::Node,settings::NamedTuple)
    return nothing
end

function undo_discount_fixed_costs!(system::System, settings::NamedTuple)
    for a in system.assets
        undo_discount_fixed_costs!(a, settings)
    end
end

function undo_discount_fixed_costs!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        undo_discount_fixed_costs!(getfield(a, t), settings)
    end
end

function undo_discount_fixed_costs!(y::Union{AbstractEdge,AbstractStorage},settings::NamedTuple)
    # Number of years of payments that are remaining
    model_years_remaining = sum(settings.StageLengths[stage_index(y):end]; init = 0);
    payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);
    y.investment_cost = investment_cost(y) / sum(1 / (1 + wacc(y))^s for s in 1:payment_years_remaining; init=0);
    opexmult = sum([1 / (1 + settings.WACC)^(i - 1) for i in 1:settings.StageLengths[stage_index(y)]])
    y.fixed_om_cost = fixed_om_cost(y) / opexmult
end
function undo_discount_fixed_costs!(g::Transformation,settings::NamedTuple)
    return nothing
end
function undo_discount_fixed_costs!(n::Node,settings::NamedTuple)
    return nothing
end