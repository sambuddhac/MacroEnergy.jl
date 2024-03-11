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
abstract type CO2 <: Commodity end

abstract type AbstractTypeConstraint end

abstract type TransformationType end

abstract type NaturalGasPower <: TransformationType  end
abstract type NaturalGasPowerCCS <: TransformationType  end
abstract type NaturalGasHydrogen <: TransformationType  end
abstract type NaturalGasHydrogenCCS <: TransformationType  end
abstract type FuelCell <: TransformationType end
abstract type Electrolyzer <: TransformationType  end
abstract type DACElectric <: TransformationType  end
abstract type SyntheticNG <: TransformationType  end

# type hierarchy

# globals

# const Containers = JuMP.Containers
# const VariableRef = JuMP.VariableRef
const JuMPConstraint = Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray}
# const DataFrameRow = DataFrames.DataFrameRow;
# const DataFrame = DataFrames.DataFrame;

# include files
include("constraints.jl")
include("node.jl")
include("edge.jl")
include("resource.jl")
include("storage.jl")
include("transformation.jl")
include("config/configure_settings.jl")
include("load_inputs/load_dataframe.jl")
include("load_inputs/load_timeseries.jl")
include("load_inputs/load_inputs.jl")
include("load_inputs/load_network.jl")
include("load_inputs/load_transformations.jl")
include("load_inputs/load_resources.jl")
include("load_inputs/load_storage.jl")
include("load_inputs/load_variability.jl")
include("input_translation/dolphyn_to_macro.jl")
include("generate_model.jl")
include("prepare_inputs.jl")

# exports
export Electricity,
    Hydrogen,
    NaturalGas,
    CO2,
    NaturalGasPower,
    NaturalGasPowerCCS,
    NaturalGasHydrogen,
    NaturalGasHydrogenCCS,
    FuelCell,
    Electrolyzer,
    DACElectric,
    SyntheticNG,
    Resource,
    Sink,
    AbstractStorage,
    SymmetricStorage,
    AsymmetricStorage,
    InputFilesNames,
    Node,
    Edge,
    Transformation,
    TEdge,
    CapacityConstraint,
    configure_settings,
    add_planning_variables!,
    add_operation_variables!,
    add_model_constraint!,
    add_all_model_constraints!,
    generate_model,
    prepare_inputs!,
    loadresources,
    makeresource,
    settings,
    nodes,
    networks,
    resources,
    storage,
    dolphyn_to_macro,
    apply_unit_conversion
end # module Macro
