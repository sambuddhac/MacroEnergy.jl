using sqlite_db

struct New_resource <: Resource
    name::String
    type::String
    zone::String
    fixedcost::Float64
    variablecost::Float64
end

function makeresource(sqlite_db)
    return New_resource(name, type, zone, fixedcost, variablecost)
end
