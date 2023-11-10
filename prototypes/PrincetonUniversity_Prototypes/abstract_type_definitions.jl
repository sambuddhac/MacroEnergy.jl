abstract type Commodity end

abstract type Power <: Commodity end

abstract type Hydrogen <: Commodity end

abstract type AbstractResource{T <: Commodity} end

abstract type AbstractStorage{T} <: AbstractResource{T} end

resource_type(g::AbstractResource{T}) where T=T;
