local test_decl = {}

local function deepEqual(x, y)
    if type(x) ~= type(y) then
        return false
    end
    if type(x) ~= "table" then
        return x == y
    end
    for k in pairs(x) do
        if not deepEqual(x[k], y[k]) then
            return false
        end
    end
    for k in pairs(y) do
        if x[k] == nil then
            return false
        end
    end
    return true
end

local function assertEqual(want, got)
    if not deepEqual(got, want) then
        error(string.format("expected `%s`, got `%s`", want, got))
    end
end

local function buildMockServer()
    local server = {
        _announce_log = {},
        _http_log = {},
    }

    function server.announce(name, message, peer_id)
        table.insert(server._announce_log, {
            name = name,
            message = message,
            peer_id = peer_id,
        })
    end

    function server.httpGet(port, request)
        table.insert(server._http_log, {
            port = port,
            request = request,
        })
    end

    return server
end

local function buildT()
    local env = {}
    local fn, err = loadfile("script.lua", "t", env)
    if fn == nil then
        error(err)
    end

    local t = {
        env = env,
        fn = fn,
        reset = function(self)
            for k, _ in pairs(self.env) do
                self.env[k] = nil
            end
            self.env.pairs = pairs
            self.env.ipairs = ipairs
            self.env.next = next
            self.env.tostring = tostring
            self.env.tonumber = tonumber
            self.env.type = type
            self.env.math = math
            self.env.table = table
            self.env.string = string
            self.env.server = buildMockServer()
        end,
    }

    t:reset()
    return t
end

function test_decl.testOnCustomCommand(t)
    local tt = {
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?test",
            in_args = {"52149"},
            want_active = true,
            want_port = 52149,
            want_len = 0,
            want_req = "/?n=0",
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "body_len=0",
                    peer_id = nil,
                },
            },
        },
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?other",  -- !
            in_args = {"52149"},
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {},
        },
        {
            in_active = false,
            in_user_peer_id = -1,   -- !
            in_admin = true,
            in_cmd = "?test",
            in_args = {"52149"},
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {},
        },
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?test",
            in_args = {},   -- !
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: wrong number or arguments",
                    peer_id = 0,
                },
            },
        },
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?test",
            in_args = {"52149", ""},    -- !
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: wrong number or arguments",
                    peer_id = 0,
                },
            },
        },
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?test",
            in_args = {"52149.0"},  -- !
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: invalid port number",
                    peer_id = 0,
                },
            },
        },
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?test",
            in_args = {"0"},    -- !
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: invalid port number",
                    peer_id = 0,
                },
            },
        },
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?test",
            in_args = {"65536"},    -- !
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: invalid port number",
                    peer_id = 0,
                },
            },
        },
        {
            in_active = true,   -- !
            in_user_peer_id = 0,
            in_admin = true,
            in_cmd = "?test",
            in_args = {"52149"},
            want_active = true,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: already running",
                    peer_id = 0,
                },
            },
        },
        {
            in_active = false,
            in_user_peer_id = 0,
            in_admin = false,   -- !
            in_cmd = "?test",
            in_args = {"52149"},
            want_active = false,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: permission denied",
                    peer_id = 0,
                },
            },
        },
        {
            in_active = true,           -- !
            in_user_peer_id = 0,
            in_admin = false,           -- !
            in_cmd = "?other",          -- !
            in_args = {"52149.0", ""},  -- !
            want_active = true,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {},
        },
        {
            in_active = true,           -- !
            in_user_peer_id = -1,       -- !
            in_admin = false,           -- !
            in_cmd = "?test",
            in_args = {"52149.0", ""},  -- !
            want_active = true,
            want_port = nil,
            want_len = nil,
            want_req = nil,
            want_announce_log = {},
        },
    }

    for ti, tc in ipairs(tt) do
        t:reset()
        t.fn()
        t.env.g_active = tc.in_active
        t.env.g_port = nil
        t.env.g_len = nil
        t.env.g_req = nil

        t.env.onCustomCommand("", tc.in_user_peer_id, tc.in_admin, false, tc.in_cmd, table.unpack(tc.in_args))

        assertEqual(tc.want_active, t.env.g_active)
        assertEqual(tc.want_port, t.env.g_port)
        assertEqual(tc.want_len, t.env.g_len)
        assertEqual(tc.want_req, t.env.g_req)
        assertEqual(tc.want_announce_log, t.env.server._announce_log)
    end
end

function test_decl.testHttpReply(t)
    local tt = {
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=0",
            in_resp = "",
            want_g_active = true,
            want_g_port = 52149,
            want_g_len = 1,
            want_g_req = "/?n=1",
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "body_len=1",
                    peer_id = nil,
                },
            },
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 1,       -- !
            in_g_req = "/?n=1", -- !
            in_port = 52149,
            in_req = "/?n=1",   -- !
            in_resp = "1",      -- !
            want_g_active = true,
            want_g_port = 52149,
            want_g_len = 2,
            want_g_req = "/?n=2",
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "body_len=2",
                    peer_id = nil,
                },
            },
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 16,                  -- !
            in_g_req = "/?n=16",            -- !
            in_port = 52149,
            in_req = "/?n=16",              -- !
            in_resp = "0000000000000000",   -- !
            want_g_active = true,
            want_g_port = 52149,
            want_g_len = 17,
            want_g_req = "/?n=17",
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "body_len=17",
                    peer_id = nil,
                },
            },
        },
        {
            in_g_active = false,    -- !
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=0",
            in_resp = "",
            want_g_active = false,
            want_g_port = 52149,
            want_g_len = 0,
            want_g_req = "/?n=0",
            want_announce_log = {},
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52150,    -- !
            in_req = "/?n=0",
            in_resp = "",
            want_g_active = true,
            want_g_port = 52149,
            want_g_len = 0,
            want_g_req = "/?n=0",
            want_announce_log = {},
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=1",   -- !
            in_resp = "",
            want_g_active = true,
            want_g_port = 52149,
            want_g_len = 0,
            want_g_req = "/?n=0",
            want_announce_log = {},
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=0",
            in_resp = "0",  -- !
            want_g_active = false,
            want_g_port = nil,
            want_g_len = nil,
            want_g_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: response length mismatch\n" ..
                        "expected_body_len=0\n" ..
                        "received_body_len=1\n" ..
                        "received_body=\"0\"",
                    peer_id = nil,
                },
            },
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=0",
            in_resp = "123456789012345678901234567890123456789012345678901234567890123",    -- !
            want_g_active = false,
            want_g_port = nil,
            want_g_len = nil,
            want_g_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: response length mismatch\n" ..
                        "expected_body_len=0\n" ..
                        "received_body_len=63\n" ..
                        "received_body=\"123456789012345678901234567890123456789012345678901234567890123\"",
                    peer_id = nil,
                },
            },
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=0",
            in_resp = "1234567890123456789012345678901234567890123456789012345678901234",   -- !
            want_g_active = false,
            want_g_port = nil,
            want_g_len = nil,
            want_g_req = nil,
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "error: response length mismatch\n" ..
                        "expected_body_len=0\n" ..
                        "received_body_len=64",
                    peer_id = nil,
                },
            },
        },
        {
            in_g_active = false,    -- !
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=0",
            in_resp = "0",          -- !
            want_g_active = false,
            want_g_port = 52149,
            want_g_len = 0,
            want_g_req = "/?n=0",
            want_announce_log = {},
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52150,    -- !
            in_req = "/?n=0",
            in_resp = "0",      -- !
            want_g_active = true,
            want_g_port = 52149,
            want_g_len = 0,
            want_g_req = "/?n=0",
            want_announce_log = {},
        },
        {
            in_g_active = true,
            in_g_port = 52149,
            in_g_len = 0,
            in_g_req = "/?n=0",
            in_port = 52149,
            in_req = "/?n=1",   -- !
            in_resp = "0",      -- !
            want_g_active = true,
            want_g_port = 52149,
            want_g_len = 0,
            want_g_req = "/?n=0",
            want_announce_log = {},
        },
    }

    for ti, tc in ipairs(tt) do
        t:reset()
        t.fn()
        t.env.g_active = tc.in_g_active
        t.env.g_port = tc.in_g_port
        t.env.g_len = tc.in_g_len
        t.env.g_req = tc.in_g_req

        t.env.httpReply(tc.in_port, tc.in_req, tc.in_resp)

        assertEqual(tc.want_g_active, t.env.g_active)
        assertEqual(tc.want_g_port, t.env.g_port)
        assertEqual(tc.want_g_len, t.env.g_len)
        assertEqual(tc.want_g_req, t.env.g_req)
        assertEqual(tc.want_announce_log, t.env.server._announce_log)
    end
end

function test_decl.testHttpGet(t)
    local tt = {
        {
            in_active = false,
            in_port = nil,
            in_len = nil,
            want_req = nil,
            want_announce_log = {},
            want_http_log = {},
        },
        {
            in_active = true,
            in_port = 52149,
            in_len = 0,
            want_req = "/?n=0",
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "body_len=0",
                    peer_id = nil
                },
            },
            want_http_log = {
                {
                    port = 52149,
                    request = "/?n=0",
                },
            },
        },
        {
            in_active = true,
            in_port = 52149,
            in_len = 1,
            want_req = "/?n=1",
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "body_len=1",
                    peer_id = nil
                },
            },
            want_http_log = {
                {
                    port = 52149,
                    request = "/?n=1",
                },
            },
        },
        {
            in_active = true,
            in_port = 52149,
            in_len = 255,
            want_req = "/?n=255",
            want_announce_log = {
                {
                    name = "[sw-test-resplen]",
                    message = "body_len=255",
                    peer_id = nil
                },
            },
            want_http_log = {
                {
                    port = 52149,
                    request = "/?n=255",
                },
            },
        },
    }

    for ti, tc in ipairs(tt) do
        t:reset()
        t.fn()
        t.env.g_active = tc.in_active
        t.env.g_port = tc.in_port
        t.env.g_len = tc.in_len
        t.env.g_req = nil

        t.env.httpGet()

        assertEqual(tc.want_req, t.env.g_req)
        assertEqual(tc.want_announce_log, t.env.server._announce_log)
        assertEqual(tc.want_http_log, t.env.server._http_log)
    end
end

local function test()
    local test_tbl = {}
    for test_name, test_fn in pairs(test_decl) do
        table.insert(test_tbl, {
            name = test_name,
            fn = test_fn,
        })
    end

    table.sort(test_tbl, function(x, y)
        return x.name < y.name
    end)

    local function msgh(err)
        return {
            err = err,
            traceback = debug.traceback(),
        }
    end

    local t = buildT()
    local s = "PASS"
    for _, test_entry in ipairs(test_tbl) do
        t:reset()
        local is_success, err = xpcall(test_entry.fn, msgh, t)
        if is_success then
            io.write(string.format("PASS %s\n", test_entry.name))
        else
            io.write(string.format("FAIL %s\n", test_entry.name))
            io.write(string.format("%s\n", err.err))
            io.write(string.format("%s\n", err.traceback))
            s = "FAIL"
        end
    end
    io.write(string.format("%s\n", s))
end

test()
