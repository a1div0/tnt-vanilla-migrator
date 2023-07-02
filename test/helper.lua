local test = require('luatest')
local fio = require('fio')

local TARANTOOL_WORKDIR = 'test/data'
local TARANTOOL_LISTEN = 3301
local TEST_DIRNAME = TARANTOOL_WORKDIR .. '/migrate/'

test.before_suite(function()
    fio.rmtree(TARANTOOL_WORKDIR)
    fio.mktree(TARANTOOL_WORKDIR)
    fio.mktree(TEST_DIRNAME)

    box.cfg{
        wal_dir = TARANTOOL_WORKDIR,
        memtx_dir = TARANTOOL_WORKDIR,
        listen = TARANTOOL_LISTEN,
    }

    box.schema.user.grant('guest', 'read,write,execute,create,alter,drop', 'universe', nil, {if_not_exists=true})
end)

local function load_file(filename)
    local file = fio.open(filename, {'O_RDONLY'})
    local data = file:read()
    file:close()

    return data
end

return {
    test_dirname = TEST_DIRNAME,
    load_file = load_file,
}
