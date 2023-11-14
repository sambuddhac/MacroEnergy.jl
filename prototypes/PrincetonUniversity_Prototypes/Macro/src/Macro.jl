module Macro

import JuMP

# Type parameter for Macro data structures
abstract type Commodity end

abstract type Electricity <: Commodity end
abstract type Hydrogen <: Commodity end

# type hierarchy

# globals
const TimeLength = 10;
const Containers = JuMP.Containers
const VariableRef = JuMP.VariableRef
const DenseAxisArray = JuMP.Containers.DenseAxisArray
const time_interval_map = Dict(Electricity=>1:TimeLength,Hydrogen=>5:5:TimeLength);
# const Component = Union{AbstractResource,AbstractEdge} # move it to the file where it is used

# include files
include("constraints.jl")
include("resource.jl")
include("storage.jl")
include("edge.jl")

# exports
export  Electricity, Hydrogen, 
        VRE, Solar, BaseResource,
        SymmetricStorage, AsymmetricStorage, 
        Edge, 
        CapacityConstraint, 
        add_planning_variables!, 
        add_operation_variables!, 
        add_fixed_cost!, add_variable_cost!, 
        add_model_constraint!,
        add_all_model_constraints!
    
end # module Macro