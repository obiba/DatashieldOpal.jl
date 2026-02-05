using DataShieldOpal
using Documenter

DocMeta.setdocmeta!(
    DataShieldOpal,
    :DocTestSetup,
    :(using DataShieldOpal);
    recursive = true,
)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [DataShieldOpal],
    authors = "Hugo Solleder <hugo.solleder@epfl.ch>",
    repo = "https://github.com/obiba/DataShieldOpal.jl/blob/{commit}{path}#{line}",
    sitename = "DataShieldOpal.jl",
    format = Documenter.HTML(; canonical = "https://obiba.github.io/DataShieldOpal.jl"),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/obiba/DataShieldOpal.jl")
