using Macro

# test_case_path = joinpath("ExampleSystems", "Macro_3Zone_SmallNewEngland")
test_case_path = joinpath(dirname(dirname(@__DIR__)), "ExampleSystems", "Macro_3Zone_SmallNewEngland")

macro_settings = Macro.configure_settings(joinpath(test_case_path, "Settings", "macro_settings.yml"))

transformations, T = load_transformations_json(joinpath(test_case_path,"transforms"), macro_settings)