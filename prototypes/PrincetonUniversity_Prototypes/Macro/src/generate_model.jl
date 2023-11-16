function generate_model(resources::Vector{AbstractResource},setup::Dict)

    model = Model()

    @variable(model,vREF==1);

    @expression(model,eFixedCost,0*model[:vREF]);
    
    @expression(model,eVariableCost,0*model[:vREF]);

    add_planning_variables!.(resources,model)

    add_operation_variables!.(resources, model)

    add_all_model_constraints!.(resources,model)

    add_fixed_costs!.(resources,model)

    add_variable_costs!.(resources,model)

    @objective(model,Min,model[:eFixedCost] + model[:eVariableCost])

    return model

end