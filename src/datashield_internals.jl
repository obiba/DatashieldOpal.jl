"""
    _datashield_profiles(opal::OpalObject)

Get available Datashield profiles

# Arguments
- `opal`: An `OpalObject` instance.
"""
function _datashield_profiles(opal::OpalObject)
    if opal.version < v"4.2"
        return Dict{String,Any}("available" => "default", "current" => "default")
    else
        return Dict{String,Any}(
            "available" => map(x -> x["name"], opal_get(opal, "datashield", "profiles")),
            "current" => isnothing(opal.profile) ? "default" : opal.profile,
        )
    end
end
