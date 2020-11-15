## 1.2.0 (2020-11-15)

* Attempt support for [activerecord-sqlserver-adapter](https://github.com/rails-sqlserver/activerecord-sqlserver-adapter) (@janko)

* Attempt support for [oracle-enhanced](https://github.com/rsim/oracle-enhanced) Active Record adapter (@janko)

## 1.1.0 (2020-11-08)

* Drop support for Ruby 2.2 (@janko)

* Support transaction/savepoint hooks even when Active Record holds the transaction/savepoint (@janko)

* Don't test the connection on `Sequel.connect` by default (@janko)

## 1.0.1 (2020-10-28)

* Use Active Record connection lock in `Database#synchronize` (@janko)

## 1.0.0 (2020-10-25)

* Clear AR statement cache on `ActiveRecord::PreparedStatementCacheExpired` when Sequel holds the transaction (@janko)

* Pick up `ActiveRecord::Base.default_timezone` being changed on runtime (@janko)

* Support prepared statements and bound variables in all adapters (@janko)

* Correctly identify identity columns as primary keys in Postgres adapter (@janko)

* Avoid using deprecated `sqlite3` API in SQLite adapter (@janko)

* Allow using any external Active Record adapters (@janko)

* Avoid potential bugs when converting Active Record exceptions into Sequel exceptions (@janko)

* Don't use Active Record locks when executing queries with Sequel (@janko)

* Support `Database#valid_connection?` in Postgres adapter (@janko)

* Fully utilize Sequel's logic for detecting disconnects in Postgres adapter (@janko)

* Support `Database#{copy_table,copy_into,listen}` in Postgres adapter (@janko)

* Log all queries executed by Sequel (@janko)

* Log executed queries to Sequel logger(s) as well (@janko)

* Specially label queries executed by Sequel in Active Record logs (@janko)

## 0.4.1 (2020-09-28)

* Require Sequel version 5.16.0 or above (@janko)

## 0.4.0 (2020-09-28)

* Return correct result of `Database#in_transaction?` after ActiveRecord transaction exited (@janko)

* Make ActiveRecord create a savepoint inside a Sequel transaction with `auto_savepoint: true` (@janko)

* Make Sequel create a savepoint inside ActiveRecord transaction with `joinable: false` (@janko)

* Improve reliability of nested transactions when combining Sequel and ActiveRecord (@janko)

* Raise error when attempting to add an `after_commit`/`after_rollback` hook on ActiveRecord transaction (@janko)

* Fix infinite loop that could happen with transactional Rails tests (@janko)

## 0.3.0 (2020-07-24)

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
