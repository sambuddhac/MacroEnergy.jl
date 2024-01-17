import Macro
import Test
using Logging, LoggingExtras


test_logger = ConsoleLogger(stderr, Logging.Warn)

with_logger(test_logger) do
    Test.@testset "Configuration" begin
        include("test_config.jl")
    end

    Test.@testset verbose = true "Load Inputs" begin
        include("test_load_inputs.jl")
    end

    Test.@testset "Resource" begin
        include("test_resources.jl")
    end
end
