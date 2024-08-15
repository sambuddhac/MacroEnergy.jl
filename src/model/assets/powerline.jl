struct PowerLine <: AbstractAsset
    elec_edge::Edge{Electricity}
end
id(b::PowerLine) = b.elec_edge.id

