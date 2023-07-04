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
tarantoolctl rocks install https://raw.githubusercontent.com/a1div0/tnt-vanilla-migrator/main/tnt-vanilla-migrator-1.0.0-0.rockspec
```