local helper = require("test.helper")
local t = require("luatest")
local g = t.group()

local tnt_vanilla_migrator = require('tnt-vanilla-migrator')
--require('lua-debug-helper').run()

local TEST_DATA = {
    {
        id = 1,
        number = 3.14,
        string = ",,',,,,\n,,,\",,,\"\",,",
        any = { a = 5, b = 6 },
    },
    {
        id = 2,
        number = 5e+20,
        string = "Съешь эти мягкие французские булочки, да выпей чаю",
        any = {1, 2, 3, 4, 5},
    },
    {
        id = 3,
        number = 0,
        string = "{}",
        any = nil,
    },
}

g.before_all(function()
    local space1 = box.schema.space.create('my_table', { if_not_exists = true })
    local fields = {
        {name = 'id', type = 'unsigned'},
        {name = 'number', type = 'number'},
        {name = 'string', type = 'string'},
        {name = 'any', type = 'any', is_nullable = true},
    }
    space1:format(fields)

    space1:create_index('primary', {
        parts = {'id'},
        type = 'tree',
        unique = true,
        if_not_exists = true,
    })

    local space2 = box.schema.space.create('altered_table', { if_not_exists = true })
    local fields2 = {
        {name = 'id', type = 'unsigned'},
        {name = 'number', type = 'number'},
        {name = 'too', type = 'number'},
        {name = 'foo', type = 'string'},
        {name = 'string', type = 'string'},
        {name = 'any', type = 'any', is_nullable = true},
    }
    space2:format(fields2)

    space2:create_index('primary', {
        parts = {'id'},
        type = 'tree',
        unique = true,
        if_not_exists = true,
    })
end)

g.after_each(function()
    box.space.my_table:truncate()
    box.space.altered_table:truncate()
end)

g.test_export = function()
    local space = box.space.my_table

    for _, record in pairs(TEST_DATA) do
        local tuple = space:frommap(record)
        space:insert(tuple)
    end

    tnt_vanilla_migrator.export(helper.test_dirname)

    local need_data = helper.load_file('test/fixtures/my_table.jdata')
    local actual_data = helper.load_file('test/data/migrate/my_table.jdata')

    t.assert_equals(need_data, actual_data)
end

g.test_export_sequence = function()
    local rv = box.schema.sequence.create('rv')
    rv:next()
    rv:next()
    rv:next()
    tnt_vanilla_migrator.export(helper.test_dirname)

    rv:drop()

    local need_data = helper.load_file('test/fixtures/_sequence.jdata')
    local actual_data = helper.load_file('test/data/migrate/_sequence.jdata')

    t.assert_equals(need_data, actual_data)
end

g.test_import_sequence = function()
    tnt_vanilla_migrator.import('test/fixtures/_sequence.jdata', { create = true })

    local rv = box.sequence.rv
    t.assert(rv, 'Seuence rv exist')
    t.assert_equals(rv:current(), 3, 'Значение счётчика')
    rv:drop()
end

g.test_import_from_file = function()
    tnt_vanilla_migrator.import('test/fixtures/my_table.jdata')
    local cnt = box.space.my_table:count()
    t.assert_equals(cnt, 3, 'Число записей')
end

g.test_import_from_directory = function()
    tnt_vanilla_migrator.import('test/fixtures/', { create = true })
    local cnt = box.space.my_table:count()
    t.assert_equals(cnt, 3, 'Число записей')
    local rv = box.sequence.rv
    t.assert(rv, 'Seuence rv exist')
    rv:drop()
end

g.test_simple_import = function()
    tnt_vanilla_migrator.import('test/fixtures/my_table.jdata')

    local space = box.space.my_table
    local ctr = 0
    for _, tuple in space:pairs() do
        ctr = ctr + 1
        local record = tuple:tomap({ names_only = true })
        t.assert_equals(TEST_DATA[record.id or ctr], record)
    end

    t.assert_equals(ctr, 3, 'Число записей')
end

g.test_failure_import__need_default = function()
    local opt = {
        my_table = {
            new_space_name = 'altered_table',
            default_values = {
                too = 0,
            }
        }
    }

    local ok, err = pcall(tnt_vanilla_migrator.import, 'test/fixtures/my_table.jdata', opt)
    t.assert_equals(ok, false)
    t.assert_equals(type(err), 'string')
    t.assert(err:find('Need set default values for field dest space: foo'))
end

g.test_import_to_altered_table = function()
    local opt = {
        my_table = {
            new_space_name = 'altered_table',
            default_values = {
                too = 0,
                foo = 'default',
            }
        }
    }

    tnt_vanilla_migrator.import('test/fixtures/my_table.jdata', opt)

    local check_data = table.deepcopy(TEST_DATA)
    for _, value in pairs(check_data) do
        value.too = opt.my_table.default_values.too
        value.foo = opt.my_table.default_values.foo
    end

    local space = box.space.altered_table
    local ctr = 0
    for _, tuple in space:pairs() do
        ctr = ctr + 1
        local record = tuple:tomap({ names_only = true })
        t.assert_equals(check_data[record.id or ctr], record)
    end

    t.assert_equals(ctr, 3, 'Число записей')
end
