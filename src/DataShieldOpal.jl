module DataShieldOpal

using Opal: OpalObject, opal_login, opal_get

abstract type DSObject end

abstract type DSDriver <: DSObject end

struct OpalDriver <: DSDriver end

function Opal()
    return OpalDriver()
end

export Opal

abstract type DSConnection <: DSObject end

include("OpalConnection.jl")
export dsConnect, dsListTables, dsHasTable

end
