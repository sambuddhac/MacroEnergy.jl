@doc raw"""
timestepbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64})

Determines the time step that is h steps bßefore index t in
subperiod p with circular indexing.

"""
function timestepbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64}})::Int
    #Find the subperiod that contains time t
    p = subperiods[findfirst(t .∈ subperiods)]; 
    #circular shift of the subperiod forward by h steps
    pc = circshift(p,h); 

    return pc[findfirst(p.==t)]

end