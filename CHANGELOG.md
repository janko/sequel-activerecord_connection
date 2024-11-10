## 2.0.0 (2024-11-10)

* The `after_commit_everywhere` gem now needs to be added to the Gemfile manually on Active Record < 7.2 (@janko)

## 1.5.1 (2024-11-08)

* Add support for Active Record 8.0 (@phlipper)

## 1.5.0 (2024-10-16)

* Avoid permanent connection checkout on Active Record 7.2+ (@janko)

## 1.4.3 (2024-09-26)

* Fix compatibility with adapters that don't support savepoints (@janko)

## 1.4.2 (2024-09-23)

* Fix compatibility with newer versions of Oracle Enhanced adapter (@janko)

* Drop support for Ruby 2.4 (@janko)

## 1.4.1 (2024-05-10)

* Fix `#rollback_checker`, `#rollback_on_exit` and `#after_rollback` not working reliably on JRuby and Sequel 5.78+ (@janko)

* Use native transaction callbacks on Active Record 7.2+ (@janko)

## 1.4.0 (2024-03-19)

* Only warn when Sequel extension fails to initialize because there is no database (@janko)

* Drop support for Active Record 4.2 (@janko)

## 1.3.1 (2023-04-22)

* Fix Active Record's query cache not being cleared in SQLite adapter (@janko)

## 1.3.0 (2023-04-22)

* Clear Active Record query cache after Sequel executes SQL statements (@janko)

## 1.2.11 (2023-01-09)

* Raise explicit exception in case of mismatch between Active Record and Sequel adapter (@janko)

## 1.2.10 (2022-12-13)

* Fix incorrect PG type mapping when using prepared statements in Sequel (@janko)

## 1.2.9 (2022-03-15)

* Remove `sequel_pg` and `pg` runtime dependencies introduced in the previous version (@janko)

## 1.2.8 (2022-02-28)

* Support the pg_streaming database extension from the sequel_pg gem (@janko)

## 1.2.7 (2022-01-20)

* Require Sequel 5.38+ (@janko)

## 1.2.6 (2021-12-26)

* Speed up connection access by avoiding checking Active Record version at runtime (@janko)

## 1.2.5 (2021-12-19)

* Loosen Active Record dependency to allow any 7.x version (@janko)

* Drop support for Ruby 2.3 (@janko)

* Allow using the `sql_log_normalizer` Sequel database extension (@janko)

## 1.2.4 (2021-09-27)

* Allow using with Active Record 7.0 (@janko)

* Use `ActiveRecord.default_timezone` on Active Record 7.0 or greater (@janko)

## 1.2.3 (2021-07-17)

* Bump `after_commit_everywhere` dependency to `~> 1.0` (@wivarn)

## 1.2.2 (2021-01-11)

* Ensure Active Record queries inside a Sequel transaction are typemapped correctly in postgres adapter (@janko)

* Fix executing Active Record queries inside a Sequel transaction not working in mysql2 adapter (@janko)

## 1.2.1 (2021-01-10)

* Fix original mysql2 query options not being restored after nested `DB#synchronize` calls, e.g. when using Sequel transactions (@janko)

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
