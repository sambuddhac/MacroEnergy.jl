
function generate_operational_subproblems(system_vec::Vector{Vector{Any}})

    subproblem_vec = generate_subproblem.(system_vec);
    
    return subproblem_vec

end

function generate_subproblem(system::Vector{Any})
    model = Model()

    @variable(model, vREF == 1)

    @expression(model, eVariableCost, 0 * model[:vREF])

    add_subproblem_planning_variables!.(system,Ref(model))

    add_operation_variables!.(system, Ref(model))

    add_operation_constraints!.(system, Ref(model))

    @objective(model, Min, model[:eVariableCost])

    return model

end

function generate_master(system::Vector{Any},subperiods::Vector{StepRange{Int64,Int64}})
    model = Model()

    @variable(model, vREF == 1)

    @expression(model, eFixedCost, 0 * model[:vREF])

    add_planning_variables!.(system,Ref(model))

    add_planning_constraints!.(system, Ref(model))

    @variable(model,theta[w in subperiods].>=0)

    @objective(model, Min, model[:eFixedCost] + sum(theta))

    return model

end
