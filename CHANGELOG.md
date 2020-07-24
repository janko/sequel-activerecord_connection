## HEAD

* Fully support Sequel transaction API (all transaction options, transaction/savepoint hooks etc.) (@janko)

## 0.2.6 (2020-07-19)

* Return block result in `Sequel::Database#transaction` (@zabolotnov87, @janko)

* Fix `Sequel::Model#save_changes` or `#save` with additional options not executing (@zabolotnov87, @janko)

## 0.2.5 (2020-06-04)

* Use `#current_timestamp_utc` for the JDBC SQLite adapter as well (@HoneyryderChuck)

## 0.2.4 (2020-06-03)

* Add JRuby support for ActiveRecord 6.0 and 5.2 (@HoneyryderChuck)

* Use `#current_timestamp_utc` setting for SQLite adapter on Sequel >= 5.33 (@HoneyryderChuck)

## 0.2.3 (2020-05-25)

* Fix Ruby 2.7 kwargs warnings in `#transaction` (@HoneyryderChuck)

## 0.2.2 (2020-05-02)

* Add support for ActiveRecord 4.2 (@janko)

## 0.2.1 (2020-05-02)

* Add support for Active Record 5.0, 5.1 and 5.2 (@janko)

* Allow Sequel 4.x (@janko)

## 0.2.0 (2020-04-29)

* Rename to `sequel-activerecord_connection` and make it a Sequel extension (@janko)
