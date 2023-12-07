function add_fixed_costs!(g::AbstractResource, model::Model)

    model[:eFixedCost] +=
        g.investment_cost * new_capacity(g) + g.fixed_om_cost * capacity(g)

end


function add_fixed_costs!(g::SymmetricStorage, model::Model)

    model[:eFixedCost] +=
        g.investment_cost * new_capacity(g) + g.fixed_om_cost * capacity(g)

    model[:eFixedCost] +=
        g.investment_cost_storage * new_capacity_storage(g) +
        g.fixed_om_cost_storage * capacity_storage(g)

end

function add_fixed_costs!(g::AsymmetricStorage, model::Model)

    model[:eFixedCost] +=
        g.investment_cost * new_capacity(g) + g.fixed_om_cost * capacity(g)

    model[:eFixedCost] +=
        g.investment_cost_storage * new_capacity_storage(g) +
        g.fixed_om_cost_storage * capacity_storage(g)

    model[:eFixedCost] +=
        g.investment_cost_withdrawal * new_capacity_withdrawal(g) +
        g.fixed_om_cost_withdrawal * capacity_withdrawal(g)

end

function add_variable_costs!(g::AbstractResource, model::Model)

    for t in time_interval(g)
        add_to_expression!(model[:eVariableCost], g.variable_om_cost * injection(g)[t]); #TODO: put this back when we have add price timeseries to resources ### + sum(price(g) .* injection(g))
    end

end
function add_variable_costs!(g::AbstractStorage, model::Model)

    for t in time_interval(g)
        add_to_expression!(model[:eVariableCost], g.variable_om_cost_withdrawal * withdrawal(g)[t])
    end

end

function add_fixed_costs!(e::AbstractEdge, model::Model)

    model[:eFixedCost] += e.investment_cost * new_capacity(e)

end
