@doc raw"""
timestepbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64})

Determines the time step that is h steps bßefore index t in
subperiod p with circular indexing.

"""
function timestepbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64}})::Int
    #Find the subperiod that contains time t
    p = findfirst(t .∈ subperiods); 
    n = length(p);
    
    return mod1(t-h-1,n)+1

end