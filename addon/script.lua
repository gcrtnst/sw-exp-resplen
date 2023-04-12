c_annouce_name = "[sw-test-resplen]"

g_active = false
g_port = nil
g_len = nil
g_limit = nil
g_step = nil
g_req = nil

function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, cmd, ...)
    if cmd ~= "?test" or user_peer_id < 0 then
        return
    end

    local args = {...}
    if #args < 1 or 4 < #args then
        server.announce(c_annouce_name, "error: wrong number or arguments", user_peer_id)
        return
    end

    local port = tonumber(args[1], 10)
    if port == nil or port < 1 or 65535 < port then
        server.announce(c_annouce_name, "error: invalid port number", user_peer_id)
        return
    end

    local start = 0
    if #args >= 2 then
        start = tonumber(args[2], 10)
        if start == nil or start < 0 then
            server.announce(c_annouce_name, "error: invalid start number", user_peer_id)
            return
        end
    end

    local limit = 1 << 30   -- 1 GiB
    if #args >= 3 then
        limit = tonumber(args[3], 10)
        if limit == nil or limit < 0 then
            server.announce(c_annouce_name, "error: invalid limit number", user_peer_id)
            return
        end
    end

    local step = 1
    if #args >= 4 then
        step = tonumber(args[4], 10)
        if step == nil or step < 1 then
            server.announce(c_annouce_name, "error: invalid step number", user_peer_id)
            return
        end
    end

    if g_active then
        server.announce(c_annouce_name, "error: already running", user_peer_id)
        return
    end

    if not is_admin then
        server.announce(c_annouce_name, "error: permission denied", user_peer_id)
        return
    end

    g_active = true
    g_port = port
    g_len = start
    g_limit = limit
    g_step = step
    testNext()
end

function httpReply(port, req, resp)
    if not g_active or port ~= g_port or req ~= g_req then
        return
    end
    g_req = nil

    local err = nil
    if #resp ~= g_len then
        err = "response length mismatch"
    end
    if string.match(resp, "^%.*$") == nil then
        err = "response content mismatch"
    end
    if err ~= nil then
        local msg = string.format(
            (
                "error: %s\n" ..
                "expected_body_len=%d\n" ..
                "received_body_len=%d"
            ),
            err,
            g_len,
            #resp
        )
        if #resp < 64 then
            -- Assume that resp contains only printable ASCII characters.
            -- Otherwise server.announce will print nothing (not even error messages).
            msg = string.format("%s\nreceived_body=%q", msg, resp)
        end

        server.announce(c_annouce_name, msg)
        testStop()
        return
    end

    g_len = g_len + 1
    testNext()
end

function testNext()
    if not g_active then
        return
    end

    local req = string.format("/?n=%d", g_len)
    server.httpGet(g_port, req)
    g_req = req

    server.announce(c_annouce_name, string.format("body_len=%d", g_len))
end

function testStop()
    g_active = false
    g_port = nil
    g_len = nil
    g_limit = nil
    g_step = nil
end
