package = 'tnt-vanilla-migrator'
version = '1.2.0-0'
source  = {
    url    = 'git+https://github.com/a1div0/tnt-vanilla-migrator.git';
    branch = 'main';
    tag = '1.2.0'
}
description = {
    summary  = 'Export to file and import from file';
    homepage = 'https://github.com/a1div0/tnt-vanilla-migrator';
    maintainer = "Alexander Klenov <a.a.klenov@ya.ru>";
    license  = 'UNLICENSE';
}
dependencies = {
    'lua >= 5.1',
    'tarantool',
}
build = {
    type = 'builtin';
    modules = {
        ['tnt-vanilla-migrator'] = 'tnt-vanilla-migrator/init.lua',
    }
}
