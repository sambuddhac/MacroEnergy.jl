const UNITS = Dict{Symbol,Symbol}(
    :Electricity => :MWh,
    :Hydrogen => :MWh,
    :NaturalGas => :MWh,
    :CO2 => :t,
    :CO2Captured => :t,
    :Biomass => :t,
    :Uranium => :t
)

unit(commodity::Symbol) = UNITS[commodity]
unit(commodity::DataType) = unit(Symbol(commodity))