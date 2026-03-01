
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

    opal = OpalObject(;
        username=username,
        password=password,
        token=token,
        url=url,
        opts=opts,
        profile=profile,
    )

    return OpalConnection(name, opal)
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
