# Sequel::ActiveRecordConnection

This is an extension for [Sequel] that allows it to reuse an existing
ActiveRecord connection for database interaction. It works on ActiveRecord 4.2
or higher, and supports the built-in `postgresql`, `mysql2` and `sqlite3`
adapters, as well as JDBC adapter for JRuby.

This can be useful if you're using a library that uses Sequel for database
interaction (e.g. [Rodauth]), but you want to avoid creating a separate
database connection. Or if you're transitioning from ActiveRecord to Sequel,
and want the database connection to be shared.

Note that this is a best-effort implementation, so some discrepancies are still
possible. That being said, this implementation passes Rodauth's test suite
(for all adapters), which has some fairly advanced Sequel usage.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sequel-activerecord_connection", "~> 0.3"
```

And then execute:

```sh
$ bundle install
```

Or install it yourself as:

```sh
$ gem install sequel-activerecord_connection
```

## Usage

Assuming you've configured your ActiveRecord connection, you can initialize the
appropriate Sequel adapter and load the `activerecord_connection` extension:

```rb
require "sequel"

DB = Sequel.postgres(extensions: :activerecord_connection)
```

Now any Sequel operations that you make will internaly be done using the
ActiveRecord connection, so you should see the queries in your ActiveRecord
logs.

```rb
DB.create_table :posts do
  primary_key :id
  String :title, null: false
  Stirng :body, null: false
end

DB[:posts].insert(
  title: "Sequel::ActiveRecordConnection",
  body:  "Allows Sequel to reuse ActiveRecord's connection",
)
#=> 1

DB[:posts].all
#=> [{ title: "Sequel::ActiveRecordConnection", body: "Allows Sequel to reuse ActiveRecord's connection" }]

DB[:posts].update(title: "sequel-activerecord_connection")
#=> 1
```

The database extension supports `postgresql`, `mysql2` and `sqlite3`
ActiveRecord adapters, just make sure to initialize the corresponding Sequel
adapter before loading the extension.

```rb
DB = Sequel.postgres(extensions: :activerecord_connection) # for "postgresql" adapter
# or
DB = Sequel.mysql2(extensions: :activerecord_connection) # for "mysql2" adapter
# or
DB = Sequel.sqlite(extensions: :activerecord_connection) # for "sqlite3" adapter
# or
DB = Sequel.jdbc(extensions: :activerecord_connection) # for JDBC adapter
```

### Transactions

This database extension keeps the transaction state of Sequel and ActiveRecord
in sync, allowing you to use Sequel and ActiveRecord transactions
interchangeably (including nesting them), and have things like ActiveRecord's
and Sequel's transactional callbacks still work correctly.

```rb
ActiveRecord::Base.transaction do
  DB.in_transaction? #=> true
end
```

Sequel's transaction API is fully supported:

```rb
DB.transaction(isolation: :serializable) do
  DB.after_commit { ... } # call block after transaction commits
  DB.transaction(savepoint: true) do # creates a savepoint
    # ...
  end
end
```

One caveat to keep in mind is that Sequel's transaction hooks
(`after_commit`, `after_rollback`) will *not* run if ActiveRecord holds the
outer transaction:

```rb
DB.transaction do
  DB.after_commit { ... } # will get executed
end

ActiveRecord::Base.transaction do
  DB.after_commit { ... } # won't get executed
end

ActiveRecord::Base.transaction do
  DB.transaction do
    DB.after_commit { ... } # won't get executed
  end
end
```

Savepoint hooks should still work, though:

```rb
ActiveRecord::Base.transaction do
  DB.transaction(savepoint: true) do
    DB.after_commit { ... } # will get executed after savepoint is released
  end
end
```

### Model

By default, the connection configuration will be read from `ActiveRecord::Base`.
If you want to use connection configuration from a different model, you can
can assign it to the database object after loading the extension:

```rb
class MyModel < ActiveRecord::Base
  connects_to database: { writing: :animals, reading: :animals_replica }
end
```
```rb
DB.activerecord_model = MyModel
```

### Timezone

Sequel's database timezone will be automatically set to ActiveRecord's default
timezone (`:utc` by default) when the extension is loaded.

If you happen to be changing ActiveRecord's default timezone after you've
loaded the extension, make sure to reflect that in your Sequel database object,
for example:

```rb
DB.timezone = :local
```

## Tests

You'll first want to run the rake tasks for setting up databases and users:

```sh
$ rake db_setup_postgres
$ rake db_setup_mysql
```

Then you can run the tests:

```sh
$ rake test
```

When you're done, you can delete the created databases and users:

```sh
$ rake db_teardown_postgres
$ rake db_teardown_mysql
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/janko/sequel-activerecord-adapter/blob/master/CODE_OF_CONDUCT.md).

[Sequel]: https://github.com/jeremyevans/sequel
[Rodauth]: https://github.com/jeremyevans/rodauth
