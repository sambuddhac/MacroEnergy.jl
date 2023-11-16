abstract type AbstractSubperiod{T<:Commodity} end

Base.@kwdef mutable struct Subperiod{T<:Commodity}
    start_time :: Int64 = first(time_interval_map[T])
    end_time :: Int64 = last(time_interval_map[T])
end

