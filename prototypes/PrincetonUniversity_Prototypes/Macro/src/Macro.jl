module Macro

using YAML
using CSV
using DataFrames
using JuMP

# Type parameter for Macro data structures
abstract type Commodity end

abstract type Electricity <: Commodity end
abstract type Hydrogen <: Commodity end
abstract type NaturalGas <: Commodity end

abstract type AbstractTypeConstraint{T<:Commodity} end

#abstract type AbstractTypeTransformationConstraint end

# type hierarchy

# globals

# const Containers = JuMP.Containers
# const VariableRef = JuMP.VariableRef
const JuMPConstraint = Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray}
# const DataFrameRow = DataFrames.DataFrameRow;
# const DataFrame = DataFrames.DataFrame;

# include files
include("node.jl")
include("resource.jl")
include("storage.jl")
#include("transformation.jl")
include("config/configure_settings.jl")
include("edge.jl")
include("load_inputs/load_inputs.jl")
include("load_inputs/load_dataframe.jl")
include("load_inputs/load_resources.jl")
include("load_inputs/load_variability.jl")
include("generate_model.jl")
include("prepare_inputs.jl")
include("constraints.jl")
include("costs.jl")

function commodity_type(c::AbstractString)
        T::DataType = eval(Symbol(c))
        @assert (T <: Commodity)
        return T
end


# exports
export Electricity,
    Hydrogen,
    Resource,
    Thermal,
    BaseResource,
    SymmetricStorage,
    AsymmetricStorage,
    Edge,
    CapacityConstraint,
    configure_settings,
    add_planning_variables!,
    add_operation_variables!,
    add_fixed_cost!,
    add_variable_cost!,
    add_model_constraint!,
    add_all_model_constraints!,
    generate_model,
    prepare_inputs!,
    loadresources,
    makeresource,
    InputFilesNames,
    load_dataframe,
    load_resources,
    load_variability!
end # module Macro
