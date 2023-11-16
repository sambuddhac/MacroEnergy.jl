using Macro
using Documenter

DocMeta.setdocmeta!(Macro, :DocTestSetup, :(using Macro); recursive = true)

makedocs(;
    modules = [Macro],
    authors = "",
    sitename = "Macro",
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", "false") == "true"),
    pages = ["Home" => "index.md"],
)

# deploydocs(;
#     repo="https://github.com/macroenergy/Macro",
#     target = "build",
#     branch = "gh-pages",
#     devurl = "dev",
#     push_preview=true,
# )
