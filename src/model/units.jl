const DEFAULT_UNITS = Dict{Symbol,Symbol}(
    :Electricity => :MWh,
    :Hydrogen => :MWh,
    :NaturalGas => :MWh,
    :CO2 => :t,
    :CO2Captured => :t,
    :Biomass => :t,
    :Uranium => :t
)

"""
    unit(commodity::Symbol)

Returns the default unit for a commodity `commodity` as a Julia `Symbol`.

# Arguments
- `commodity::Symbol`: The commodity to get the unit of. 

# Returns
- `Symbol`: The default unit corresponding to the input commodity. 

# Example
```julia
unit(:Electricity)
MWh
```
"""
unit(commodity::Symbol) = DEFAULT_UNITS[commodity]
unit(commodity::DataType) = unit(Symbol(commodity))