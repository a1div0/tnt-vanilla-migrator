local fio = require('fio')
local json = require('json')

local LEN_DELIMITER = " "
local REC_DELIMITER = "\n"

local function write_block(file_handle, value)
    local result
    local string = json.encode(value)
    local n = string:len()
    result = file_handle:write(n .. LEN_DELIMITER)
            and file_handle:write(string .. REC_DELIMITER)
    if not result then
        error('IO write error!')
    end
end

local function read_block(file_handle)
    local buf = ''
    local c = ''
    local err

    while c ~= LEN_DELIMITER do
        buf = buf .. c
        c, err = file_handle:read(1)
        if err then
            error('Block read error: IO error - ' .. err)
        end
        if c == nil or c == "" then
            return nil
        end
    end

    local block_length = tonumber64(buf)
    local block = file_handle:read(block_length)
    local delimiter = file_handle:read(1)
    if delimiter ~= REC_DELIMITER then
        error('Block read error: Not finded record delimiter')
    end

    return json.decode(block)
end

local function export_space(dirname, space)
    local bits = tonumber('0666',8)
    local f, err = fio.open(dirname .. space.name .. '.jdata', {'O_RDWR', 'O_CREAT'}, bits)
    if not f then
        error('io error: ' .. err)
    end

    write_block(f, { name = space.name })
    write_block(f, space:format())

    for _, tuple in space:pairs() do
        local record = tuple:tomap({names_only = true})
        write_block(f, record)
    end

    f:close()
end

local function export_sequences(dirname)
    local bits = tonumber('0666',8)
    local f, err = fio.open(dirname .. '_sequence.jdata', {'O_RDWR', 'O_CREAT'}, bits)
    if not f then
        error('io error: ' .. err)
    end

    write_block(f, { engine = 'sequence' })

    for _, tuple in box.space._sequence:pairs() do
        local record = tuple:tomap({names_only = true})
        local value_tuple = box.space._sequence_data:get(record.id)
        if value_tuple then
            local value_record = value_tuple:tomap({names_only = true})
            record.value = value_record.value
            write_block(f, record)
        end
    end

    f:close()
end

local function export(dirname)
    for space_name, space in pairs(box.space) do
        if type(space_name) == 'string' and not space.name:startswith('_') and not space.temporary then
            export_space(dirname, space)
        end
    end
    export_sequences(dirname)
end

local function check_format(dst_format, src_format, defaults)
    local unset = {}

    for _, item in pairs(dst_format) do
        unset[item.name] = item.type
    end

    for _, item in pairs(src_format) do
        unset[item.name] = nil
    end

    for key, _ in pairs(defaults or {}) do
        unset[key] = nil
    end

    local res = {}
    for key, _ in pairs(unset) do
        table.insert(res, key)
    end

    if #res > 0 then
        error('Need set default values for field dest space: ' .. table.concat(res, ', '))
    end
end

local function import_engine_space(f, space_info, options)
    local space_import_options = options[space_info.name] or {}

    if space_import_options.new_space_name then
        space_info.old_name = space_info.name
        space_info.name = space_import_options.new_space_name
    end

    local space = box.space[space_info.name]
    if not space then
        local err_txt = ('Space %s must be created'):format(space_info.name)
        error(err_txt)
    end

    local src_format = read_block(f) -- format
    check_format(space:format(), src_format, space_import_options.default_values)

    while true do
        local record = read_block(f)
        if not record then
            break
        end

        if space_import_options.default_values then
            for key, value in pairs(space_import_options.default_values) do
                if not record[key] then
                    record[key] = value
                end
            end
        end

        local tuple = space:frommap(record)
        space:insert(tuple)
    end
end

local function import_engine_sequence(f, options)
    while true do
        local record = read_block(f)
        if not record then
            break
        end

        local sequence = box.sequence[record.name]
        if not sequence and options.create then
            local opt = {
                start = record.start,
                min = record.min,
                max = record.max,
                cycle = record.cycle,
                cache = record.cache,
                step = record.step,
            }
            sequence = box.schema.sequence.create(record.name, opt)
        end

        sequence:set(record.value)
    end
end

local function import_file(filename, options)
    local f, err = fio.open(filename, {'O_RDONLY'})
    if not f then
        error('io error: ' .. err)
    end

    local space_info = read_block(f)
    if space_info.engine == 'sequence' then
        import_engine_sequence(f, options)
    else
        import_engine_space(f, space_info, options)
    end

    f:close()
end

local function import(dirname_or_filename, options)
    if dirname_or_filename:endswith('.jdata') then
        import_file(dirname_or_filename, options or {})
    else
        local file_list = fio.listdir(dirname_or_filename)
        for _, filename in pairs(file_list) do
            local full_filename = fio.pathjoin(dirname_or_filename, filename)
            if fio.path.is_file(full_filename) and full_filename:endswith('.jdata') then
                import_file(full_filename, options or {})
            end
        end
    end
end

return {
    export = export,
    import = import,
}
