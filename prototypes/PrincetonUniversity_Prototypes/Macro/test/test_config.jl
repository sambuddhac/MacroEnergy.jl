module TestConfig

using Macro
using Test


function test_configure_settings()
    settings = configure_settings("test_inputs/macro_settings.yml")

    # Electricity
    commodity_settings = settings.Commodities["Electricity"]
    @test commodity_settings["InputDataPath"] == "test_inputs/Electricity"
    @test commodity_settings["HoursPerTimeStep"] == 1

    # Hydrogen
    commodity_settings = settings.Commodities["Hydrogen"]
    @test commodity_settings["InputDataPath"] == "test_inputs/Hydrogen"
    @test commodity_settings["HoursPerTimeStep"] == 1

    # Natural Gas
    commodity_settings = settings.Commodities["NaturalGas"]
    @test commodity_settings["InputDataPath"] == "test_inputs/NaturalGas"
    @test commodity_settings["HoursPerTimeStep"] == 1


    # Across all commodities
    @test settings[:PeriodLength] == 24
    @test settings[:HoursPerSubperiod] == 24
    @test settings[:NetworkExpansion] == 0
    @test settings[:MultiStage] == 0

    return nothing
end

test_configure_settings()

end # module TestConfig
