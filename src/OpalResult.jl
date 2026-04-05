"""
    OpalResult

Result object from asynchronous DataSHIELD operations.

# Fields
- `conn::OpalConnection`: Connection object
- `rval::Dict{String,Any}`: Contains either 'rid' (command ID) or 'result' (synchronous result)
"""
struct OpalResult <: DSObject
    conn::OpalConnection
    rval::Dict{String,Any}
end

"""
    dsGetInfo(res::OpalResult) -> Dict

Get information about an async command including its status.

# Arguments
- `res`: OpalResult object from an async operation

# Returns
- Dict with command information: status, script, createDate, startDate, endDate, etc.

# Example
```julia
result = dsAggregate(conn, "meanDS(D\$WEIGHT)")
info = dsGetInfo(result)
println("Status: ", info["status"])
```
"""
function dsGetInfo(res::OpalResult)
    if isnothing(get(res.rval, "rid", nothing))
        return Dict("status" => "COMPLETED")
    else
        return _datashield_command(res.conn.opal, res.rval["rid"]; wait=true)
    end
end

"""
    dsIsCompleted(res::OpalResult) -> Bool

Check if async operation completed (successfully or failed).

# Arguments
- `res`: OpalResult object from an async operation

# Returns
- `true` if operation is completed or failed, `false` if still running

# Example
```julia
result = dsAggregate(conn, "meanDS(D\$WEIGHT)")
while !dsIsCompleted(result)
    sleep(0.5)
    print(".")
end
println("\\nCompleted!")
```
"""
function dsIsCompleted(res::OpalResult)
    if isnothing(get(res.rval, "rid", nothing))
        return true
    else
        cmd = _datashield_command(res.conn.opal, res.rval["rid"]; wait=false)
        status = get(cmd, "status", "")
        return status == "COMPLETED" || status == "FAILED"
    end
end

"""
    dsFetch(res::OpalResult)

Fetch the result of an async operation. Blocks until complete.

# Arguments
- `res`: OpalResult object from an async operation

# Returns
- The result value from the DataSHIELD operation

# Example
```julia
result = dsAggregate(conn, "meanDS(D\$WEIGHT)")
value = dsFetch(result)
println("Mean weight: ", value)
```
"""
function dsFetch(res::OpalResult)
    if isnothing(get(res.rval, "rid", nothing))
        return res.rval["result"]
    else
        return _datashield_command_result(res.conn.opal, res.rval["rid"]; wait=true)
    end
end
