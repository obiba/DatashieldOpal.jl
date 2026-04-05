"""
    OpalSession

Represents a DataSHIELD R session on an Opal server.

# Fields
- `conn::OpalConnection`: The connection object
"""
struct OpalSession <: DSSession
    conn::OpalConnection
end

"""
    dsIsReady(session::OpalSession) -> Bool

Check if remote R session is running and ready to receive commands.

# Arguments
- `session`: OpalSession object

# Returns
- `true` if session is running, `false` otherwise

# Example
```julia
conn = dsConnect(Opal(), "server1"; username="user", password="pass", url="https://opal-demo.obiba.org")
session = dsSession(conn; async=true)
while !dsIsReady(session)
    sleep(1)
    print(".")
end
println("\\nSession ready!")
```
"""
function dsIsReady(session::OpalSession)
    try
        return opal_session_running(session.conn.opal)
    catch
        return false
    end
end

"""
    dsStateMessage(session::OpalSession) -> String

Get human-readable message about session state.

# Arguments
- `session`: OpalSession object

# Returns
- String describing the current session state

# Example
```julia
session = dsSession(conn; async=true)
println(dsStateMessage(session))
```
"""
function dsStateMessage(session::OpalSession)
    o = session.conn.opal

    try
        # Try to get session events
        events = opal_get(o, o.context, "session", o.rid, "events")

        if !isnothing(events) && !isempty(events)
            last_msg = get(events[end], "message", "")
            if !isempty(last_msg)
                return last_msg
            end
        end

        # Fallback based on version
        if o.version >= v"5.3.0"
            return "No recent events"
        else
            return "Ready"
        end
    catch
        return "No session"
    end
end
