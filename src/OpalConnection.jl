
# TODO: parametrize OpalConnection with the connection type (username/password vs token) for multile dispatch
# TODO: parametrize OpalConnection with the url type (single vs multiple) for multiple dispatch
struct OpalConnection <: DSConnection
    name::String
    opal::OpalObject
end

"""
    dsConnect(
        drv::OpalDriver;
        name::String,
        restore::Union{Nothing,String}=nothing,
        username::Union{Nothing,String}=nothing,
        password::Union{Nothing,String}=nothing,
        token::Union{Nothing,String}=nothing,
        url::Union{Nothing,String,Vector{String}}=nothing,
        opts::Union{Nothing,Dict{String,Any}}=nothing,
        profile::Union{Nothing,String}=nothing
    )

Connect to a Opal server, with provided credentials. Does not create a DataSHIELD R session, only retrieves user profile.

# Arguments
- `drv`: `OpalDriver` class object.
- `name`: Name of the connection, which must be unique among all the DataSHIELD connections.
- `restore`: Workspace name to be restored in the newly created DataSHIELD R session.
- `username`: User name in opal(s).
- `password`: User password in opal(s).
- `token`: Personal access token (since opal 2.15, ignored if username is specified).
- `url`: Opal url
- `opts`: Curl options as described by httr (call httr::httr_options() for details).
- `profile`: The DataSHIELD R server profile (affects the R packages available and the applied configuration). If not provided or not supported, default profile will be applied.

"""
function dsConnect(
    drv::OpalDriver,
    name::String;
    restore::Union{Nothing,String}=nothing,
    username::Union{Nothing,String}=nothing,
    password::Union{Nothing,String}=nothing,
    token::Union{Nothing,String}=nothing,
    url::Union{Nothing,String,Vector{String}}=nothing,
    opts::Dict{String,Any}=Dict{String,Any}(),
    profile::Union{Nothing,String}=nothing,
)
    o = opal_login(;
        username=username,
        password=password,
        token=token,
        url=url,
        opts=opts,
        profile=profile,
        restore=restore,
        context="datashield",
    )

    return OpalConnection(name, o)
end

"""
    dsListTables(conn::OpalConnection)

List Opal tables that may be accessible for performing DDataSHIELD operations.

# Arguments
- `conn`: An `OpalConnection` object.

# Returns
- The fully qualified names of the tables.

# Example
```julia
conn = dsConnect(
    Opal(),
    "server1";
    username="administrator",
    password="password",
    url="https://opal-demo.obiba.org",
)
dsListTables(conn)
```
"""
function dsListTables(conn::OpalConnection)
    o = conn.opal
    tables = String[]
    dslist = opal_get(o, "datasources")
    if isnothing(dslist)
        return tables
    end
    for ds in dslist
        if haskey(ds, "name") && haskey(ds, "table") && !isnothing(ds["table"])
            tbls = ds["table"]
            if tbls isa String
                tbls = [tbls]
            end
            for tbl in tbls
                push!(tables, string(ds["name"], ".", tbl))
            end
        end
    end
    return tables
end

"""
    dsHasTable(conn::OpalConnection, table::String)

Verify Opal table exist and can be accessible for performing DataSHIELD operations.

# Arguments
- `conn`: An `OpalConnection` object.
- `table`: The fully qualified name of the table.

# Returns
- `true` if table exists.

# Example
```julia
conn = dsConnect(
    Opal(),
    "server1";
    username="administrator",
    password="password",
    url="https://opal-demo.obiba.org",
)
dsHasTable(conn, "test.CNSIM")
```
"""
function dsHasTable(conn::OpalConnection, table::String)
    o = conn.opal
    parts = split(table, ".")
    if length(parts) < 2
        return false
    end
    datasource = parts[1]
    name = join(parts[2:end], ".")
    try
        opal_get(o, "datasource", datasource, "table", name)
        # TODO: check if opal_get returns nothing
        return true
    catch
        return false
    end
end

"""
    dsListResources(conn::OpalConnection)

List Opal resources that may be accessible for performing DataSHIELD operations.

# Arguments
- `conn`: An `OpalConnection` object.

# Returns
- The fully qualified names of the resources.

# Example
```julia
conn = dsConnect(
    Opal(),
    "server1";
    username="administrator",
    password="password",
    url="https://opal-demo.obiba.org",
)
dsListResources(conn)
```
"""
function dsListResources(conn::OpalConnection)
    o = conn.opal
    resources = String[]
    for proj in opal_get(o, "projects")
        for res in opal_resources(o, proj["name"]; df=false)
            push!(resources, proj["name"] * "." * res["name"])
        end
    end
    if isempty(resources)
        return String[]
    end
    return resources
end

"""
    dsHasResource(conn::OpalConnection, resource::String)

Verify Opal resource exist and can be accessible for performing DataSHIELD operations.

# Arguments
- `conn`: An `OpalConnection` object.
- `resource`: The fully qualified name of the resource.

# Returns
- `true` if resource exists.

# Example
```julia
conn = dsConnect(
    Opal(),
    "server1";
    username="administrator",
    password="password",
    url="https://opal-demo.obiba.org",
)
dsHasResource(conn, "test.CNSIM")
```
"""
function dsHasResource(conn::OpalConnection, resource::String)
    o = conn.opal
    parts = split(resource, ".")
    if length(parts) < 2
        return false
    end
    project = parts[1]
    name = join(parts[2:end], ".")
    try
        opal_resource(o, project, name)
        return true
    catch
        return false
    end
end

"""
    dsHasSession(conn::OpalConnection) -> Bool

Check if a remote R session exists

# Arguments
- `conn`: An `OpalConnection` object.
# Returns
- A boolean indicating if a remote session exists accessible through this connection
"""
function dsHasSession(conn::OpalConnection)
    o = conn.opal
    return !isnothing(o.rid)
end

"""
    dsSession(conn::OpalConnection; async::Bool=true) -> OpalSession

Create a remote R session if none exists, or return existing session.

# Arguments
- `conn`: OpalConnection object
- `async`: Whether session creation should be asynchronous

# Returns
- OpalSession object representing the remote R session

# Example
```julia
conn = dsConnect(Opal(), "server1"; username="user", password="pass", url="https://opal-demo.obiba.org")
session = dsSession(conn; async=true)
```
"""
function dsSession(conn::OpalConnection; async::Bool=true)
    o = conn.opal
    opal_session(o; wait=(!async))
    return OpalSession(conn)
end

#===============================================================================
# Group 1: Connection Lifecycle
===============================================================================#

"""
    dsKeepAlive(conn::OpalConnection)

Keep connection alive by making a dummy request.

# Arguments
- `conn`: OpalConnection object

# Example
```julia
dsKeepAlive(conn)
```
"""
function dsKeepAlive(conn::OpalConnection)
    try
        dsListSymbols(conn)
    catch
        # Ignore errors
    end
    return nothing
end

"""
    dsDisconnect(conn::OpalConnection; save::Union{Nothing,String}=nothing)

Disconnect from Opal server. Optionally save workspace before disconnecting.

# Arguments
- `conn`: OpalConnection object
- `save`: Optional workspace name to save session before closing

# Example
```julia
# Disconnect without saving
dsDisconnect(conn)

# Disconnect and save workspace
dsDisconnect(conn; save="my_workspace")
```
"""
function dsDisconnect(conn::OpalConnection; save::Union{Nothing,String}=nothing)
    o = conn.opal

    # Check version for workspace support
    if !isnothing(save) && o.version < v"2.6"
        @warn "$(conn.name): Workspaces not available for opal $(o.version) (2.6.0+ required)"
    end

    # Remove DataSHIELD session
    try
        _rm_datashield_session(o, save)
    catch
        # Ignore errors during cleanup
    end

    # Clear session ID
    o.rid = nothing

    # Logout
    opal_logout(o)

    return nothing
end

#===============================================================================
# Group 2: Session & Symbol Management
===============================================================================#

"""
    dsIsAsync(conn::OpalConnection) -> Dict{String,Bool}

List async capabilities (all operations support async in Opal).

# Arguments
- `conn`: OpalConnection object

# Returns
- Dict with async support for each operation type

# Example
```julia
capabilities = dsIsAsync(conn)
println("Aggregate async: ", capabilities["aggregate"])
```
"""
function dsIsAsync(conn::OpalConnection)
    return Dict(
        "session" => true,
        "aggregate" => true,
        "assignTable" => true,
        "assignResource" => true,
        "assignExpr" => true,
    )
end

"""
    dsListSymbols(conn::OpalConnection) -> Vector{String}

List R symbols in the DataSHIELD session.

# Arguments
- `conn`: OpalConnection object

# Returns
- Vector of symbol names

# Example
```julia
dsAssignTable(conn, "D", "project.CNSIM")
symbols = dsListSymbols(conn)
println("Symbols: ", symbols)
```
"""
function dsListSymbols(conn::OpalConnection)
    return _datashield_symbols(conn.opal)
end

"""
    dsRmSymbol(conn::OpalConnection, symbol::String)

Remove an R symbol from the DataSHIELD session.

# Arguments
- `conn`: OpalConnection object
- `symbol`: Name of the R symbol to remove

# Example
```julia
dsAssignTable(conn, "D", "project.CNSIM")
dsRmSymbol(conn, "D")
```
"""
function dsRmSymbol(conn::OpalConnection, symbol::String)
    _datashield_rm(conn.opal, symbol)
    return nothing
end

#===============================================================================
# Group 3: Configuration Discovery
===============================================================================#

"""
    dsListProfiles(conn::OpalConnection) -> Dict{String,Any}

List available DataSHIELD profiles.

# Arguments
- `conn`: OpalConnection object

# Returns
- Dict with "available" (Vector{String}) and "current" (String) keys

# Example
```julia
profiles = dsListProfiles(conn)
println("Available profiles: ", profiles["available"])
println("Current profile: ", profiles["current"])
```
"""
function dsListProfiles(conn::OpalConnection)
    return _datashield_profiles(conn.opal)
end

"""
    dsListMethods(conn::OpalConnection; type::String="aggregate") -> DataFrame

List DataSHIELD methods (aggregate or assign).

# Arguments
- `conn`: OpalConnection object
- `type`: Method type - "aggregate" (default) or "assign"

# Returns
- DataFrame with columns: name, type, class, value, package, version

# Example
```julia
# List aggregate methods
agg_methods = dsListMethods(conn)

# List assign methods
assign_methods = dsListMethods(conn; type="assign")
```
"""
function dsListMethods(conn::OpalConnection; type::String="aggregate")
    return _datashield_methods(conn.opal, type)
end

"""
    dsListPackages(conn::OpalConnection) -> DataFrame

List DataSHIELD packages.

# Arguments
- `conn`: OpalConnection object

# Returns
- DataFrame with columns: package, version (unique)

# Example
```julia
packages = dsListPackages(conn)
println(packages)
```
"""
function dsListPackages(conn::OpalConnection)
    agg = dsListMethods(conn; type="aggregate")
    assign = dsListMethods(conn; type="assign")

    all_methods = DataFrames.vcat(agg, assign)

    # Select package and version columns, get unique rows
    packages = DataFrames.unique(DataFrames.select(all_methods, [:package, :version]))

    return packages
end

#===============================================================================
# Group 4: Workspace Management
===============================================================================#

"""
    dsListWorkspaces(conn::OpalConnection) -> DataFrame

List saved workspaces in the data repository.

# Arguments
- `conn`: OpalConnection object

# Returns
- DataFrame with columns: name, user, context, lastAccessDate, size

# Example
```julia
workspaces = dsListWorkspaces(conn)
println(workspaces)
```
"""
function dsListWorkspaces(conn::OpalConnection)
    if conn.opal.version < v"2.6"
        @warn "Workspaces not available for opal $(conn.opal.version) (2.6.0+ required)"
        return DataFrames.DataFrame(;
            name=String[],
            user=String[],
            context=String[],
            lastAccessDate=String[],
            size=Int[],
        )
    end
    return _datashield_workspaces(conn.opal)
end

"""
    dsSaveWorkspace(conn::OpalConnection, name::String)

Save current workspace to the data repository.

# Arguments
- `conn`: OpalConnection object
- `name`: Workspace name

# Example
```julia
dsSaveWorkspace(conn, "my_analysis")
```
"""
function dsSaveWorkspace(conn::OpalConnection, name::String)
    if conn.opal.version < v"2.6"
        @warn "Workspaces not available for opal $(conn.opal.version) (2.6.0+ required)"
        return nothing
    end
    _datashield_workspace_save(conn.opal, name)
    return nothing
end

"""
    dsRestoreWorkspace(conn::OpalConnection, name::String)

Restore a saved workspace from the data repository.

# Arguments
- `conn`: OpalConnection object
- `name`: Workspace name

# Example
```julia
dsRestoreWorkspace(conn, "my_analysis")
```
"""
function dsRestoreWorkspace(conn::OpalConnection, name::String)
    if conn.opal.version < v"4.5"
        @warn "Workspace restore not available for opal $(conn.opal.version) (4.5.0+ required)"
        return nothing
    end
    _datashield_workspace_restore(conn.opal, name)
    return nothing
end

"""
    dsRmWorkspace(conn::OpalConnection, name::String)

Remove a workspace from the data repository.

# Arguments
- `conn`: OpalConnection object
- `name`: Workspace name

# Example
```julia
dsRmWorkspace(conn, "my_analysis")
```
"""
function dsRmWorkspace(conn::OpalConnection, name::String)
    if conn.opal.version < v"2.6"
        @warn "Workspaces not available for opal $(conn.opal.version) (2.6.0+ required)"
        return nothing
    end
    _datashield_workspace_rm(conn.opal, name, conn.opal.username)
    return nothing
end

#===============================================================================
# Group 5: Data Operations
===============================================================================#

"""
    dsAssignTable(conn, symbol, table; variables=nothing, missings=false,
                  identifiers=nothing, id_name=nothing, async=true) -> OpalResult

Assign an Opal table to an R symbol in the DataSHIELD session.

# Arguments
- `conn`: OpalConnection object
- `symbol`: Name of R symbol
- `table`: Fully qualified table name (e.g., "project.table")
- `variables`: Vector of variable names or JS expression for variable selection
- `missings`: Push missing values from Opal to R (default false)
- `identifiers`: Name of identifiers mapping
- `id_name`: Column name for entity identifiers
- `async`: Execute asynchronously (default true)

# Returns
- OpalResult object for async operations

# Example
```julia
# Assign entire table
dsAssignTable(conn, "D", "datashield.CNSIM1")

# Assign specific variables
dsAssignTable(conn, "D", "datashield.CNSIM1"; variables=["GENDER", "LAB_TSC"])

# Assign with JS expression for variable selection
dsAssignTable(conn, "D", "datashield.CNSIM1"; variables="name().matches('LAB_')")
```
"""
function dsAssignTable(
    conn::OpalConnection,
    symbol::String,
    table::String;
    variables::Union{Nothing,Vector{String},String}=nothing,
    missings::Bool=false,
    identifiers::Union{Nothing,String}=nothing,
    id_name::Union{Nothing,String}=nothing,
    async::Bool=true,
)
    rval = _datashield_assign_table(
        conn.opal,
        symbol,
        table;
        variables=variables,
        missings=missings,
        identifiers=identifiers,
        id_name=id_name,
        async=async,
    )

    if async
        return OpalResult(conn, Dict("rid" => rval, "result" => nothing))
    else
        return OpalResult(conn, Dict("rid" => nothing, "result" => rval))
    end
end

"""
    dsAssignResource(conn, symbol, resource; async=true) -> OpalResult

Assign an Opal resource to an R symbol in the DataSHIELD session.

# Arguments
- `conn`: OpalConnection object
- `symbol`: Name of R symbol
- `resource`: Fully qualified resource name (e.g., "project.resource")
- `async`: Execute asynchronously (default true)

# Returns
- OpalResult object for async operations

# Example
```julia
dsAssignResource(conn, "R", "project.my_resource")
```
"""
function dsAssignResource(
    conn::OpalConnection, symbol::String, resource::String; async::Bool=true
)
    rval = _datashield_assign_resource(conn.opal, symbol, resource; async=async)

    if async
        return OpalResult(conn, Dict("rid" => rval, "result" => nothing))
    else
        return OpalResult(conn, Dict("rid" => nothing, "result" => rval))
    end
end

"""
    dsAssignExpr(conn, symbol, expr; async=true) -> OpalResult

Assign the result of an R expression to a symbol in the DataSHIELD session.

# Arguments
- `conn`: OpalConnection object
- `symbol`: Name of R symbol
- `expr`: R expression (String or Expr - will be converted to String)
- `async`: Execute asynchronously (default true)

# Returns
- OpalResult object for async operations

# Example
```julia
# Using string expression
dsAssignExpr(conn, "C", "c(1, 2, 3)")

# Using Julia Expr (will be converted to string)
dsAssignExpr(conn, "C", :(c(1, 2, 3)))
```
"""
function dsAssignExpr(
    conn::OpalConnection, symbol::String, expr::Union{String,Expr}; async::Bool=true
)
    # Convert Expr to String if needed
    expr_str = expr isa Expr ? string(expr) : expr

    rval = _datashield_assign_expr(conn.opal, symbol, expr_str; async=async)

    if async
        return OpalResult(conn, Dict("rid" => rval, "result" => nothing))
    else
        return OpalResult(conn, Dict("rid" => nothing, "result" => rval))
    end
end

"""
    dsAggregate(conn, expr; async=true) -> OpalResult

Execute an aggregation expression in the DataSHIELD session.

# Arguments
- `conn`: OpalConnection object
- `expr`: R aggregation expression (String or Expr)
- `async`: Execute asynchronously (default true)

# Returns
- OpalResult object for async operations

# Example
```julia
dsAssignTable(conn, "D", "datashield.CNSIM1")
result = dsAggregate(conn, "meanDS(D\$WEIGHT)")
value = dsFetch(result)
println("Mean weight: ", value)
```
"""
function dsAggregate(conn::OpalConnection, expr::Union{String,Expr}; async::Bool=true)
    # Convert Expr to String if needed
    expr_str = expr isa Expr ? string(expr) : expr

    rval = _datashield_aggregate(conn.opal, expr_str, async)

    if async
        return OpalResult(conn, Dict("rid" => rval, "result" => nothing))
    else
        return OpalResult(conn, Dict("rid" => nothing, "result" => rval))
    end
end
