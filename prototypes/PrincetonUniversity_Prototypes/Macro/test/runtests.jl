import Macro
import Test


Test.@testset "Configuration" begin
    include("test_config.jl")
end

Test.@testset "Load Inputs" begin
    include("test_load_inputs.jl")
end

Test.@testset "Resource" begin
    include("test_resource.jl")
end
