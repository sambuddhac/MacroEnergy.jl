
include("MACRO.jl")

all_resources = [];
push!(all_resources, VariableResource{Power}(Node = 1,R_ID=1,investment_cost=85300.0,fixed_om_cost =18760))
push!(all_resources,SymmetricStorage{Power}(Node=1,R_ID=2))
push!(all_resources,AsymmetricStorage{Power}(Node=1,R_ID=3))

model = Model()

@variable(model,vREF==1);

@expression(model,eFixedCost,0*model[:vREF]);

add_capacity_variables!.(all_resources,model)

add_fixed_costs!.(all_resources,model)

# add_capacity_constraints!.(all_resource,model)

println(model)