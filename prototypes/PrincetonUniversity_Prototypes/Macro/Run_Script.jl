cd("prototypes/PrincetonUniversity_Prototypes/Macro")
using Pkg
Pkg.activate(".")

using Macro
using JuMP

all_resources = [];

push!(all_resources,VRE{Electricity}(node = 1,r_id=1,investment_cost=85300.0,fixed_om_cost = 18760.))
push!(all_resources,SymmetricStorage{Electricity}(node=1,r_id=2))
push!(all_resources,AsymmetricStorage{Electricity}(node=1,r_id=3))

model = Model()

@variable(model,vREF==1);

@expression(model,eFixedCost,0*model[:vREF]);

@expression(model,eVariableCost,0*model[:vREF]);

add_planning_variables!.(all_resources,model)

add_operation_variables!.(all_resources,model)

add_all_model_constraints!.(all_resources,model)

add_fixed_cost!.(all_resources,model)

add_variable_cost!.(all_resources,model)

@objective(model,Min,model[:eFixedCost] + model[:eVariableCost])

println()

