abstract type AbstractOptimizationContainer end

"""
    AbstractOptimizationContainer{T}
An abstract type for optimization containers that can hold different types of optimization models.
"""

mutable struct ObjectiveFunction
    objective_expression::Union{Nothing, AbstractArray}  # The objective expression, can be empty
    sense::Symbol  # The sense of the objective ('Min', 'Max')
end

"""
    PrimalValuesCache
A cache for primal values of variables in the optimization container.
"""
mutable struct PrimalValuesCache
    variable_values::Dict{VariableKey, AbstractArray}  # Cached values of variables
    aux_variable_values::Dict{AuxVarKey, AbstractArray}  # Cached values of auxiliary variables
    dual_values::Dict{ConstraintKey, AbstractArray}  # Cached dual values
end	

"""
    InitialConditionsData
A structure to hold initial conditions data for the optimization container.
"""
mutable struct InitialConditionsData
    initial_conditions::Dict{InitialConditionKey, Vector{<:InitialCondition}}  # Initial conditions for the optimization container
    initial_conditions_data::Dict{Symbol, Any}  # Additional data related to initial conditions
end	

"""
    OptimizationContainer{T}
A mutable struct that implements the `AbstractOptimizationContainer` interface.
It holds a JuMP model, settings, variables, constraints, objective function, and other related data.
"""
mutable struct OptimizationContainer{T} <: AbstractOptimizationContainer
    JuMPmodel = JuMP.Model  # The JuMP model type
    settings::Settings
    settings_copy::Settings
    variables::Dict{VariableKey, AbstractArray}
    aux_variables::Dict{AuxVarKey, AbstractArray}
    duals::Dict{ConstraintKey, AbstractArray}
    constraints::Dict{ConstraintKey, AbstractArray}
    objective_function::ObjectiveFunction
    expressions::Dict{ExpressionKey, AbstractArray}
    parameters::Dict{ParameterKey, ParameterContainer}
    primal_values_cache::PrimalValuesCache
    initial_conditions::Dict{InitialConditionKey, Vector{<:InitialCondition}}
    initial_conditions_data::InitialConditionsData
    infeasibility_conflict::Dict{Symbol, Array}
    models::Vector{T}  # A vector of optimization models of type T
end

function OptimizationContainer(
    sys::System,
    settings::Settings,
    jump_model::Union{Nothing, JuMP.Model},
    ::Type{T},
) where {T <: AbstractTimeData{<:Commodity}}
    if isabstracttype(T)
        error("Default Time Series Type $V can't be abstract")
    end

    if jump_model !== nothing && get_direct_mode_optimizer(settings)
        throw(
            IS.ConflictingInputsError(
                "Externally provided JuMP models are not compatible with the direct model keyword argument. Use JuMP.direct_model before passing the custom model",
            ),
        )
    end

    return OptimizationContainer(
        jump_model === nothing ? JuMP.Model() : jump_model,
        settings,
        copy_for_serialization(settings),
        Dict{VariableKey, AbstractArray}(),
        Dict{AuxVarKey, AbstractArray}(),
        Dict{ConstraintKey, AbstractArray}(),
        Dict{ConstraintKey, AbstractArray}(),
        ObjectiveFunction(),
        Dict{ExpressionKey, AbstractArray}(),
        Dict{ParameterKey, ParameterContainer}(),
        PrimalValuesCache(),
        Dict{InitialConditionKey, Vector{InitialCondition}}(),
        InitialConditionsData(),
        Dict{Symbol, Array}(),
        nothing,
    )
end

"""
    create_optimization_container{T}(models::Vector{T}) where T
Creates an instance of `AbstractOptimizationContainer` with the provided models.
"""
function create_optimization_container{T}(models::Vector{T}) where T
    return AbstractOptimizationContainer{T}(models)
end	

"""
    add_model!(container::AbstractOptimizationContainer{T}, model::T) where T
Adds a new model of type T to the optimization container.
"""
function add_model!(container::OptimizationContainer{T}, model::T) where T
    push!(container.models, model)
end	

"""
    remove_model!(container::AbstractOptimizationContainer{T}, model::T) where T
Removes a model of type T from the optimization container.
If the model is not found, it raises an error.
"""
function remove_model!(container::OptimizationContainer{T}, model::T) where T
    index = findfirst(isequal(model), container.models)
    if isnothing(index)
	error("Model not found in the container.")
    else
	deleteat!(container.models, index)
    end
end

"""
    get_models(container::AbstractOptimizationContainer{T}) where T
Returns the vector of models contained in the optimization container.
"""
function get_models(container::OptimizationContainer{T}) where T
    return container.models
end	

"""
    clear_models!(container::AbstractOptimizationContainer{T}) where T
Clears all models from the optimization container.
"""
function clear_models!(container::OptimizationContainer{T}) where T
    empty!(container.models)
end	

"""
    is_empty(container::AbstractOptimizationContainer{T}) where T
Checks if the optimization container is empty.
Returns `true` if there are no models, `false` otherwise.	
"""			

function is_empty(container::OptimizationContainer{T}) where T
    return isempty(container.models)
end	

"""
    size(container::AbstractOptimizationContainer{T}) where T
Returns the number of models in the optimization container.
"""
function size(container::OptimizationContainer{T}) where T
    return length(container.models)
end	

"""
    get_model(container::AbstractOptimizationContainer{T}, index::Int) where T
Returns the model at the specified index in the optimization container.
If the index is out of bounds, it raises an error.
"""
function get_model(container::OptimizationContainer{T}, index::Int) where T
    if index < 1 || index > length(container.models)
	error("Index out of bounds.")
    else
	return container.models[index]
    end
end		

"""
    set_model!(container::AbstractOptimizationContainer{T}, index::Int, model::T) where T
Sets the model at the specified index in the optimization container to a new model.
If the index is out of bounds, it raises an error.
"""
function set_model!(container::OptimizationContainer{T}, index::Int, model::T) where T
    if index < 1 || index > length(container.models)
	error("Index out of bounds.")	
    else
	container.models[index] = model
    end
end	