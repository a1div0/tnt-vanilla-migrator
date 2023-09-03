# TNT-VANILLA-MIGRATOR
Модуль `rock` для Tarantool, предназначенный для:
- выгрузки данных в файл
- загрузки данных из файла

Возможности модуля:
- для работы не требует каких-либо дополнительных модулей и зависимостей
  (только для тестов)
- предназначен для работы с одним инстансом
- данные можно загружать в таблицы с другой схемой данных
- может работать с большими данными

## Установка
Вы можете:
* клонировать репозиторий:
``` shell
git clone https://github.com/a1div0/tnt-vanilla-migrator.git
```
* установить rock `tnt-vanilla-migrator` модуль используя `tarantoolctl`:
```shell
tarantoolctl rocks install https://raw.githubusercontent.com/a1div0/tnt-vanilla-migrator/main/tnt-vanilla-migrator-1.1.0-0.rockspec
```

## Экспорт
1. Подключаемся к инстансу
2. Выполняем команду, указав директорию в которую будут записаны данные:
```lua
require('tnt-vanilla-migrator').export('<export directory>/')
```

## Импорт
Все импортируемые объекты должны быть уже созданы. Если нет, необходимо
использовать ключ options `create = true`.
1. Подключаемся к инстансу
2. Выполняем команду, указав директорию из которой будут прочитаны данные:
```lua
require('tnt-vanilla-migrator').import('<directory or file>', options)
```

### Options
* `create` - создавать импортируемые объекты перед загрузкой данных
* `new_space_name` - при загрузке файла (одной таблицы) можно указать новое имя спейса
* `default_values` - при загрузке файла (одной таблицы) можно указать значения по умолчанию
    
Пример:
``` lua
local opt = {
    create = true,
    my_table = {
        new_space_name = 'altered_table',
        default_values = {
            too = 0,
            foo = 'default',
        }
    }
}
```
