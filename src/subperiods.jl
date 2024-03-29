@doc raw"""
    hoursbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64})

Determines the time index that is h hours before index t in
subperiod p with circular indexing.

"""
function hoursbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64}})::Int
    #Find the subperiod that contains time t
    p = findfirst(t .∈ subperiods); 
    n = length(p);
    
    return mod1(t-h-1,n)+1

end