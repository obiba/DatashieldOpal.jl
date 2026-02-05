
"""
    OpalConnection(
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
- `url`: Opal url or list of opal urls. Can be provided by "opal.url" option.
- `opts`: Curl options as described by httr (call httr::httr_options() for details). Can be provided by "opal.opts" option.
- `profile`: The DataSHIELD R server profile (affects the R packages available and the applied configuration). If not provided or not supported, default profile will be applied.

"""
# TODO: parametrize OpalConnection with the connection type (username/password vs token) for multile dispatch
# TODO: parametrize OpalConnection with the url type (single vs multiple) for multiple dispatch
struct OpalConnection <: DSConnection
    name::String
    opal::OpalObject
end
