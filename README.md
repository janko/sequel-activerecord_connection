# Sequel ActiveRecord Adapter

This gem allows the [Sequel] library to reuse an existing ActiveRecord connection.
It supports `postgresql`, `mysql2` and `sqlite3` adapters.

This can be useful if you're using a library that uses Sequel for database
interaction (e.g. [Rodauth]), but you want to avoid creating a separate
database connection. Or if you're transitioning from ActiveRecord to Sequel,
and want the database connection to be reused.

Note that this is a best-effort implementation, so some discrepancies are still
possible. However, it's worth mentioning that this gem passes [Rodauth]'s test
suite for all adapters, which has some pretty advanced Sequel usage.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sequel-activerecord-adapter"
```

And then execute:

```sh
$ bundle install
```

Or install it yourself as:

```sh
$ gem install sequel-activerecord-adapter
```

## Usage

Given you've configured your ActiveRecord connection, you can create a Sequel
database and start making queries:

```rb
require "sequel-activerecord-adapter"

DB = Sequel.activerecord
DB.create_table :posts do
  primary_key :id
  String :title, null: false
  Stirng :body, null: false
end

DB[:posts].insert(
  title: "Sequel ActiveRecord Adapter",
  body:  "Allows Sequel to reuse ActiveRecord's connection",
)
#=> 1

DB[:posts].all
#=> [{ title: "Sequel ActiveRecord Adapter", body: "Allows Sequel to reuse ActiveRecord's connection" }]

DB[:posts].update(title: "Sequel Active Record Adapter")
#=> 1
```

Since Sequel is using ActiveRecord connection object to make queries, any SQL
queries will be logged to the ActiveRecord logger.

### Transactions

The adapter overrides Sequel transactions to use ActiveRecord transcations, so
Sequel and ActiveRecord transactions can be used interchangeably.

```rb
DB.transaction do
  ActiveRecord::Base.transaction do
    # this all works
  end
end
```

The following `Sequel::Database#transaction` options are currently supported:

* `:savepoint`
* `:auto_savepoint`
* `:rollback`

Regarding transaction-related database methods, the only other one currently
supported is `Sequel::Database#in_transaction?` (`#after_commit`,
`#after_rollback` and others are not supported).

### Exceptions

To ensure Sequel compatibility, any `ActiveRecord::StatementInvalid` exceptions
will be translated into Sequel exceptions:

```rb
DB[:posts].multi_insert [{ id: 1 }, { id: 1 }] #~> Sequel::UniqueConstraintViolation
```

### Configuration

By default, the connection configuration will be read from `ActiveRecord::Base`.
If you want to use connection configuration from a different model, you can
pass the model class:

```rb
class MyModel < ActiveRecord::Base
  connects_to database: { writing: :animals, reading: :animals_replica }
end
```
```rb
Sequel.activerecord(MyModel)
```

If the correct adapter cannot be inferred from ActiveRecord configuration at
the time of initialization, you can always specify it explicitly:

```rb
Sequel.activerecord(adapter: "postgresql")
```

## Tests

The Rakefile has rake tasks for setting up and tearing down different
databases, which you need to run first.

Then you can run the tests:

```sh
$ rake test
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Sequel::Activerecord::Adapter project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/janko/sequel-activerecord-adapter/blob/master/CODE_OF_CONDUCT.md).

[Sequel]: https://github.com/jeremyevans/sequel
[Rodauth]: https://github.com/jeremyevans/rodauth
