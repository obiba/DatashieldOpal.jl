module DataShieldOpal

using Opal:
    OpalObject,
    opal_login,
    opal_logout,
    opal_get,
    opal_post,
    opal_put,
    opal_delete,
    opal_resource,
    opal_resources,
    opal_session,
    opal_session_running
using DataFrames

# TODO: move to standalone DataShieldInterface.jl package
abstract type DSObject end

abstract type DSDriver <: DSObject end
abstract type DSSession <: DSObject end
abstract type DSConnection <: DSObject end

struct OpalDriver <: DSDriver end

function Opal()
    return OpalDriver()
end

export Opal

# Include internal helper functions first
include("datashield_internals.jl")

# Include type definitions in correct order
include("OpalConnection.jl")
include("OpalSession.jl")
include("OpalResult.jl")

# Export connection management
export dsConnect, dsDisconnect, dsKeepAlive

# Export table and resource operations
export dsListTables, dsHasTable
export dsListResources, dsHasResource

# Export session management
export dsHasSession, dsSession, dsIsReady, dsStateMessage

# Export symbol management
export dsIsAsync, dsListSymbols, dsRmSymbol

# Export configuration discovery
export dsListProfiles, dsListMethods, dsListPackages

# Export workspace management
export dsListWorkspaces, dsSaveWorkspace, dsRestoreWorkspace, dsRmWorkspace

# Export data operations
export dsAssignTable, dsAssignResource, dsAssignExpr, dsAggregate

# Export result handling
export OpalResult, dsGetInfo, dsIsCompleted, dsFetch

# Export session type
export OpalSession

end
