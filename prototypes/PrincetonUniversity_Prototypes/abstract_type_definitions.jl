abstract type Commodity end

abstract type Electricity <: Commodity end

abstract type Hydrogen <: Commodity end

abstract type AbstractResource{T <: Commodity} end

abstract type AbstractStorage{T} <: AbstractResource{T} end

abstract type AbstractEdge{T <: Commodity} end

Component = Union{AbstractResource,AbstractEdge}

const TimeLength = 10;

const time_interval_map = Dict(Electricity=>1:TimeLength,Hydrogen=>5:5:TimeLength);

commodity_type(g::AbstractResource{T}) where T=T;

commodity_type(e::AbstractEdge{T}) where T=T;

time_interval(g::AbstractResource) = time_interval_map[commodity_type(g)];

time_interval(e::AbstractEdge) = time_interval_map[commodity_type(e)];