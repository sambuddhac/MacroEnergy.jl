function generate_model(system::Vector{MacroObject})

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    model[:eVariableCost] = AffExpr(0.0)

    add_planning_variables!.(system, Ref(model))

    add_operation_variables!.(system, Ref(model))

    add_all_model_constraints!.(system, Ref(model))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    return model

end

function generate_model(system::System)
    # objects = [system.locations..., system.assets...]
    objects = MacroObject[]
    for node in system.locations
        push!(objects, node)
    end
    for asset in system.assets
        component_names = fieldnames(typeof(asset))
        for name in component_names
            push!(objects, getfield(asset, name))
        end
    end
    return generate_model(objects)
end
