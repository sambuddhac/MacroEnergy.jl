function generate_model(inputs::InputData)

    resources = reduce(vcat,[inputs.resources[c] for c in keys(inputs.resources)]);

    edges = reduce(vcat,[inputs.networks[c] for c in keys(inputs.networks)]);

    nodes = reduce(vcat,[inputs.nodes[c] for c in keys(inputs.nodes)]);
 
    storage =  [reduce(vcat,[inputs.storage[c].s for c in keys(inputs.storage)]);reduce(vcat,[inputs.storage[c].a for c in keys(inputs.storage)])];

    components = [resources; storage; edges];

    system = [nodes; components];

    model = Model()

    @variable(model, vREF == 1)

    @expression(model, eFixedCost, 0 * model[:vREF])

    @expression(model, eVariableCost, 0 * model[:vREF])

    add_planning_variables!.(components, model)

    add_operation_variables!.(system, model)
   
    add_all_model_constraints!.(system, model)

    add_fixed_costs!.(components, model)

    add_variable_costs!.(resources, model)

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    return model

end
