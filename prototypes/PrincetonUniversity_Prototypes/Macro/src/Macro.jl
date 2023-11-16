module Macro

using JuMP
using DataFrames
using CSV

# Type parameter for Macro data structures
abstract type Commodity end

abstract type Electricity <: Commodity end
abstract type Hydrogen <: Commodity end

abstract type AbstractTypeConstraint{T <: Commodity} end

# type hierarchy

# globals

# const Containers = JuMP.Containers
# const VariableRef = JuMP.VariableRef
const JuMPConstraint = Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray}
# const DataFrameRow = DataFrames.DataFrameRow;
# const DataFrame = DataFrames.DataFrame;

# include files
include("resource.jl")
include("storage.jl")
include("edge.jl")
include("generate_model.jl")
include("prepare_inputs.jl")
include("constraints.jl")
include("variables.jl")
include("costs.jl")

# exports
export  Electricity, Hydrogen, 
        Resource, Thermal, BaseResource,
        SymmetricStorage, AsymmetricStorage, 
        Edge, 
        CapacityConstraint, 
        add_planning_variables!, 
        add_operation_variables!, 
        add_fixed_cost!, add_variable_cost!, 
        add_model_constraint!,
        add_all_model_constraints!,
        generate_model,
        prepare_inputs!,
        loadresources,
        makeresource
end # module Macro