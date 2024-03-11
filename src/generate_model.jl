
function add_all_model_constraints!(
    y::Union{AbstractResource,AbstractEdge,AbstractNode},
    model::Model,
)

    for ct in all_constraints(y)
        add_model_constraint!(ct, y, model)
    end
    ##### This does not work because can't broadcast when passing g : add_model_constraints!.(all_constraints(g),g,model);

    return nothing
end

function generate_model(inputs::InputData)

    resources = reduce(vcat, [inputs.resources[c] for c in keys(inputs.resources)])

    edges = reduce(vcat, [inputs.networks[c] for c in keys(inputs.networks)])

    nodes = reduce(vcat, [inputs.nodes[c] for c in keys(inputs.nodes)])

    storage = [
        reduce(vcat, [inputs.storage[c].s for c in keys(inputs.storage)])
        reduce(vcat, [inputs.storage[c].a for c in keys(inputs.storage)])
    ]

    transformations = reduce(vcat, [inputs.transformations[c] for c in keys(inputs.transformations)]);

    components = [resources; storage; edges; transformations]

    system = [nodes; components]

    model = Model()

    @variable(model, vREF == 1)

    @expression(model, eFixedCost, 0 * model[:vREF])

    @expression(model, eVariableCost, 0 * model[:vREF])

    add_planning_variables!.(components, Ref(model))

    add_operation_variables!.(system, Ref(model))

    add_all_model_constraints!.(system, Ref(model))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    return model

end
