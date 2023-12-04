package_folder = "/Users/lb9239/Documents/ZERO_lab/Macro/Macro/prototypes/PrincetonUniversity_Prototypes/Macro"
repl_folder = pwd()

if package_folder != repl_folder
    cd(package_folder)
end

using Pkg
Pkg.activate(".")

using Macro

example_path = "ExampleSystems/SmallNewEngland/"

settings = configure_settings(joinpath(example_path, "macro_settings.yml"))

inputs = load_inputs(settings, example_path);
