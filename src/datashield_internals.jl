using DataFrames: DataFrame

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

"""
    _datashield_symbols(opal::OpalObject) -> Vector{String}

Get R symbols from the DataSHIELD session.

# Arguments
- `opal`: An `OpalObject` instance.
"""
function _datashield_symbols(opal::OpalObject)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end
    result = opal_get(opal, opal.context, "session", opal.rid, "symbols")
    if isnothing(result)
        return String[]
    end
    return result
end

"""
    _datashield_rm(opal::OpalObject, symbol::String)

Remove an R symbol from the DataSHIELD session.

# Arguments
- `opal`: An `OpalObject` instance.
- `symbol`: Name of the R symbol to remove.
"""
function _datashield_rm(opal::OpalObject, symbol::String)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end
    try
        opal_delete(opal, opal.context, "session", opal.rid, "symbol", symbol)
    catch
        # Ignore errors
    end
    return nothing
end

"""
    _rm_datashield_session(opal::OpalObject, save::Union{Nothing,String})

Remove the DataSHIELD R session, optionally saving workspace.

# Arguments
- `opal`: An `OpalObject` instance.
- `save`: Optional workspace name to save before removal.
"""
function _rm_datashield_session(opal::OpalObject, save::Union{Nothing,String})
    if !isnothing(opal.rid)
        query = Dict{String,Any}()
        if !isnothing(save)
            query["save"] = save
        end
        try
            opal_delete(opal, opal.context, "session", opal.rid; query=query)
        catch
            # Ignore errors during cleanup
        end
    end
    return nothing
end

"""
    _datashield_methods(opal::OpalObject, type::String) -> DataFrame

Get DataSHIELD methods (aggregate or assign).

# Arguments
- `opal`: An `OpalObject` instance.
- `type`: Method type - "aggregate" or "assign".

# Returns
- DataFrame with columns: name, type, class, value, package, version
"""
function _datashield_methods(opal::OpalObject, type::String)
    profile = isnothing(opal.profile) ? nothing : opal.profile
    query = isnothing(profile) ? Dict{String,Any}() : Dict{String,Any}("profile" => profile)

    rlist = opal_get(opal, "datashield", "env", type, "methods"; query=query)

    if isnothing(rlist) || isempty(rlist)
        return DataFrame(;
            name=String[],
            type=String[],
            class=String[],
            value=String[],
            package=String[],
            version=String[],
        )
    end

    names = String[]
    types = String[]
    classes = String[]
    values = String[]
    packages = String[]
    versions = String[]

    for m in rlist
        push!(names, get(m, "name", ""))
        push!(types, type)

        # Determine class (function or script)
        if haskey(m, "DataShield.RFunctionDataShieldMethodDto.method") &&
            haskey(m["DataShield.RFunctionDataShieldMethodDto.method"], "func")
            push!(classes, "function")
            push!(
                values, get(m["DataShield.RFunctionDataShieldMethodDto.method"], "func", "")
            )
            push!(
                packages,
                get(m["DataShield.RFunctionDataShieldMethodDto.method"], "rPackage", ""),
            )
            push!(
                versions,
                get(m["DataShield.RFunctionDataShieldMethodDto.method"], "version", ""),
            )
        elseif haskey(m, "DataShield.RScriptDataShieldMethodDto.method") &&
            haskey(m["DataShield.RScriptDataShieldMethodDto.method"], "script")
            push!(classes, "script")
            push!(
                values, get(m["DataShield.RScriptDataShieldMethodDto.method"], "script", "")
            )
            push!(packages, "")
            push!(versions, "")
        else
            push!(classes, "")
            push!(values, "")
            push!(packages, "")
            push!(versions, "")
        end
    end

    return DataFrame(;
        name=names,
        type=types,
        class=classes,
        value=values,
        package=packages,
        version=versions,
    )
end

"""
    _datashield_workspaces(opal::OpalObject) -> DataFrame

Get saved workspaces from the data repository.

# Arguments
- `opal`: An `OpalObject` instance.

# Returns
- DataFrame with columns: name, user, context, lastAccessDate, size
"""
function _datashield_workspaces(opal::OpalObject)
    query = Dict{String,Any}("context" => "R")
    wss = opal_get(opal, "service", "r", "workspaces"; query=query)

    if isnothing(wss) || isempty(wss)
        return DataFrame(;
            name=String[],
            user=String[],
            context=String[],
            lastAccessDate=String[],
            size=Int[],
        )
    end

    names = String[]
    users = String[]
    contexts = String[]
    dates = String[]
    sizes = Int[]

    for ws in wss
        push!(names, get(ws, "name", ""))
        push!(users, get(ws, "user", ""))
        push!(contexts, get(ws, "context", ""))
        push!(dates, get(ws, "lastAccessDate", ""))
        push!(sizes, get(ws, "size", 0))
    end

    return DataFrame(;
        name=names, user=users, context=contexts, lastAccessDate=dates, size=sizes
    )
end

"""
    _datashield_workspace_save(opal::OpalObject, name::String)

Save the current workspace to the data repository.

# Arguments
- `opal`: An `OpalObject` instance.
- `name`: Workspace name.
"""
function _datashield_workspace_save(opal::OpalObject, name::String)
    u = opal.username
    if isnothing(u) || isempty(u)
        throw(ErrorException("User name is missing or empty"))
    end
    if isempty(name)
        throw(ErrorException("Workspace name is missing or empty"))
    end
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end
    if opal.version < v"2.6"
        throw(
            ErrorException(
                "$(opal.name): Workspaces are not available for opal $(opal.version) (2.6.0 or higher is required)",
            ),
        )
    end
    query = Dict{String,Any}("save" => name)
    opal_post(opal, "datashield", "session", opal.rid, "workspaces"; query=query)
    return nothing
end

"""
    _datashield_workspace_restore(opal::OpalObject, name::String)

Restore a saved workspace from the data repository.

# Arguments
- `opal`: An `OpalObject` instance.
- `name`: Workspace name.
"""
function _datashield_workspace_restore(opal::OpalObject, name::String)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end
    opal_put(opal, opal.context, "session", opal.rid, "workspace", name)
    return nothing
end

"""
    _datashield_workspace_rm(opal::OpalObject, name::String, user::Union{Nothing,String})

Remove a workspace from the data repository.

# Arguments
- `opal`: An `OpalObject` instance.
- `name`: Workspace name.
- `user`: User name (if nothing, uses current user).
"""
function _datashield_workspace_rm(
    opal::OpalObject, name::String, user::Union{Nothing,String}
)
    u = isnothing(user) ? opal.username : user
    if isnothing(u) || isempty(u)
        throw(ErrorException("User name is missing or empty"))
    end
    if isempty(name)
        throw(ErrorException("Workspace name is missing or empty"))
    end

    query = Dict{String,Any}("context" => "R", "name" => name, "user" => u)
    opal_delete(opal, "service", "r", "workspaces"; query=query)
    return nothing
end

"""
    _datashield_assign_table(opal, symbol, value; variables, missings, identifiers, id_name, async)

Assign an Opal table to an R symbol in the DataSHIELD session.

# Arguments
- `opal`: An `OpalObject` instance.
- `symbol`: Name of the R symbol.
- `value`: Fully qualified table name.
- `variables`: List of variable names or JS expression.
- `missings`: Push missing values to R.
- `identifiers`: Identifiers mapping name.
- `id_name`: Column name for entity identifiers.
- `async`: Execute asynchronously.
"""
function _datashield_assign_table(
    opal::OpalObject,
    symbol::String,
    value::String;
    variables::Union{Nothing,Vector{String},String}=nothing,
    missings::Bool=false,
    identifiers::Union{Nothing,String}=nothing,
    id_name::Union{Nothing,String}=nothing,
    async::Bool=true,
)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end

    # Build query parameters
    query = Dict{String,Any}("missings" => missings)

    # Handle variables parameter
    if !isnothing(variables)
        if variables isa Vector{String}
            # Convert vector to JS expression: name().any('var1','var2')
            var_filter = "name().any('" * join(variables, "','") * "')"
            query["variables"] = var_filter
        else
            # String - use as-is (JS expression)
            query["variables"] = variables
        end
    end

    if !isnothing(identifiers)
        query["identifiers"] = identifiers
    end
    if !isnothing(id_name)
        query["id"] = id_name
    end
    if async
        query["async"] = "true"
    end

    result = opal_put(
        opal,
        opal.context,
        "session",
        opal.rid,
        "symbol",
        symbol;
        query=query,
        body=value,
        contentType="application/x-opal",
    )

    return result
end

"""
    _datashield_assign_resource(opal, symbol, value; async)

Assign an Opal resource to an R symbol in the DataSHIELD session.

# Arguments
- `opal`: An `OpalObject` instance.
- `symbol`: Name of the R symbol.
- `value`: Fully qualified resource name.
- `async`: Execute asynchronously.
"""
function _datashield_assign_resource(
    opal::OpalObject, symbol::String, value::String; async::Bool=true
)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end

    query = Dict{String,Any}()
    if async
        query["async"] = "true"
    end

    result = opal_put(
        opal,
        opal.context,
        "session",
        opal.rid,
        "symbol",
        symbol;
        query=query,
        body=value,
        contentType="application/x-opal",
    )

    return result
end

"""
    _datashield_assign_expr(opal, symbol, expr; async)

Assign the result of an R expression to a symbol in the DataSHIELD session.

# Arguments
- `opal`: An `OpalObject` instance.
- `symbol`: Name of the R symbol.
- `expr`: R expression as string.
- `async`: Execute asynchronously.
"""
function _datashield_assign_expr(
    opal::OpalObject, symbol::String, expr::String; async::Bool=true
)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end

    query = Dict{String,Any}()
    if async
        query["async"] = "true"
    end

    result = opal_put(
        opal,
        opal.context,
        "session",
        opal.rid,
        "symbol",
        symbol;
        query=query,
        body=expr,
        contentType="application/x-rscript",
    )

    return result
end

"""
    _datashield_aggregate(opal, expr, async)

Execute an aggregation expression in the DataSHIELD session.

# Arguments
- `opal`: An `OpalObject` instance.
- `expr`: R aggregation expression as string.
- `async`: Execute asynchronously.
"""
function _datashield_aggregate(opal::OpalObject, expr::String, async::Bool)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end

    query = Dict{String,Any}("async" => async ? "true" : "false")

    result = opal_post(
        opal,
        "datashield",
        "session",
        opal.rid,
        "aggregate";
        query=query,
        body=expr,
        contentType="application/x-rscript",
        acceptType="application/octet-stream",
    )

    return result
end

"""
    _datashield_command(opal, id; wait=false)

Get information about an asynchronous command.

# Arguments
- `opal`: An `OpalObject` instance.
- `id`: Command ID.
- `wait`: Wait for command to complete.

# Returns
- Dict with command information (id, script, status, etc.)
"""
function _datashield_command(opal::OpalObject, id::String; wait::Bool=false)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end

    query = Dict{String,Any}()
    if wait
        query["wait"] = "true"
    end

    return opal_get(opal, opal.context, "session", opal.rid, "command", id; query=query)
end

"""
    _datashield_command_result(opal, id; wait=true)

Get the result of an asynchronous command.

# Arguments
- `opal`: An `OpalObject` instance.
- `id`: Command ID.
- `wait`: Wait for command to complete.

# Returns
- The command result.
"""
function _datashield_command_result(opal::OpalObject, id::String; wait::Bool=true)
    if isnothing(opal.rid)
        throw(ErrorException("Remote DataSHIELD R session not available"))
    end

    if wait
        cmd = _datashield_command(opal, id; wait=true)
        if get(cmd, "status", "") == "FAILED"
            error_msg = get(cmd, "error", "<no message>")
            throw(
                ErrorException("Command '$(get(cmd, "script", ""))' failed: $(error_msg)")
            )
        end
    end

    return opal_get(
        opal,
        "datashield",
        "session",
        opal.rid,
        "command",
        id,
        "result";
        acceptType="application/octet-stream",
    )
end
