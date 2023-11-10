using JuMP

const TimeLength = 8760;

const time_resolution_map = Dict(Power=>Int(TimeLength/1),Hydrogen=>Int(TimeLength/4));

include("abstract_type_definitions.jl")
include("resource.jl")
include("storage.jl")
