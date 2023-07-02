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

local function export(dirname)
    for space_name, space in pairs(box.space) do
        if type(space_name) == 'string' and not space.name:startswith('_') and not space.temporary then
            export_space(dirname, space)
        end
    end
end

local function import_file(filename, options)
    local f, err = fio.open(filename, {'O_RDONLY'})
    if not f then
        error('io error: ' .. err)
    end

    local space_info = read_block(f)
    local space_import_options = options[space_info.name]

    if space_import_options and space_import_options.new_space_name then
        space_info.old_name = space_info.name
        space_info.name = space_import_options.new_space_name
    end

    local space = box.space[space_info.name]

    local _ = read_block(f) -- format
    while true do
        local record = read_block(f)
        if not record then
            break
        end

        if space_import_options and space_import_options.default_values then
            for key, value in pairs(space_import_options.default_values) do
                if not record[key] then
                    record[key] = value
                end
            end
        end

        local tuple = space:frommap(record)
        space:insert(tuple)
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
