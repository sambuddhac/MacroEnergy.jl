module TestConfig

using Macro
using Test


function test_configure_settings()
    settings = configure_settings("test_inputs/macro_settings.yml")

    @test settings[:InputDataPath] == "test_inputs"
    @test settings[:OutputDataPath] == "test_outputs"
    @test settings[:TimeDomainReductionFolder] == "TDR_Results"
    @test settings[:PrintModel] == 0
    @test settings[:NetworkExpansion] == 0
    @test settings[:TimeDomainReduction] == 0
    @test settings[:MultiStage] == 0

    return nothing
end

test_configure_settings()

end # module TestConfig
