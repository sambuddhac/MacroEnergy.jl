function generate_model(resources::Vector{AbstractResource},edges::Vector{AbstractEdge},nodes::Vector{AbstractNode},setup::Dict)
    components = [resources;edges];

    system = [resources;edges;nodes];

    model = Model()

    @variable(model,vREF==1);

    @expression(model,eFixedCost,0*model[:vREF]);
    
    @expression(model,eVariableCost,0*model[:vREF]);

    add_planning_variables!.(components,model)

    add_operation_variables!.(nodes,model)

    for y in components
        add_operation_variables!(y,nodes,model)
    end

    add_all_model_constraints!.(system,model)

    add_fixed_costs!.(components,model)

    add_variable_costs!.(resources,model)

    @objective(model,Min,model[:eFixedCost] + model[:eVariableCost])

    return model

end