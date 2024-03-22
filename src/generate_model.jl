function generate_model(inputs::InputData)

    edges = reduce(vcat, [inputs.networks[c] for c in keys(inputs.networks)])

    nodes = reduce(vcat, [inputs.nodes[c] for c in keys(inputs.nodes)])

    transformations = reduce(vcat, [inputs.transformations[c] for c in keys(inputs.transformations)]);

    system = [nodes; edges; transformations]

    model = Model()

    @variable(model, vREF == 1)

    @expression(model, eFixedCost, 0 * model[:vREF])

    @expression(model, eVariableCost, 0 * model[:vREF])

    add_planning_variables!.(system, Ref(model))

    add_operation_variables!.(system, Ref(model))

    add_all_model_constraints!.(system, Ref(model))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    return model

end
