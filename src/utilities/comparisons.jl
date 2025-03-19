function compare(a,b)
    return a == b
end

function compare(a::Missing,b)
    return ismissing(b)
end

function compare(a,b::Missing)
    return ismissing(a)
end

function compare(a::Missing,b::Missing)
    return true
end

function Base.:(==)(a::MacroObject, b::MacroObject)
    return all([compare(getproperty(a,prop),getproperty(b,prop)) for prop in propertynames(a)])
end

function find_diff(a::MacroObject, b::MacroObject)
    return [prop for prop in propertynames(a) if !compare(getproperty(a,prop),getproperty(b,prop))]
end

function Base.hash(a::MacroObject, h::UInt)
    ht = hash(MacroObject, h)
    for prop in propertynames(a)
        ht = hash(getproperty(a,prop), ht)
    end
    return ht
end

function Base.:(==)(a::AbstractTimeData, b::AbstractTimeData)
    return all([compare(getproperty(a,prop),getproperty(b,prop)) for prop in propertynames(a)])
end

function find_diff(a::AbstractTimeData, b::AbstractTimeData)
    return [prop for prop in propertynames(a) if compare(getproperty(a,prop),getproperty(b,prop))]
end

function Base.hash(a::AbstractTimeData, h::UInt)
    ht = hash(AbstractTimeData, h)
    for prop in propertynames(a)
        ht = hash(getproperty(a,prop), ht)
    end
    return ht
end

function Base.:(==)(a::AbstractTypeConstraint, b::AbstractTypeConstraint)
    return all([compare(getproperty(a,prop),getproperty(b,prop)) for prop in propertynames(a)])
end

function find_diff(a::AbstractTypeConstraint, b::AbstractTypeConstraint)
    return [prop for prop in propertynames(a) if compare(getproperty(a,prop),getproperty(b,prop))]
end

function Base.hash(a::AbstractTypeConstraint, h::UInt)
    ht = hash(AbstractTypeConstraint, h)
    for prop in propertynames(a)
        ht = hash(getproperty(a,prop), ht)
    end
    return ht
end