source "https://rubygems.org"

gemspec

gem "rake", "~> 12.0"

platform :mri do
  gem "pg",      "~> 1.0"
  gem "mysql2",  "~> 0.5"
  gem "sqlite3", "~> 1.3"
end

platform :jruby do
  gem "activerecord-jdbc-adapter"
  gem "jdbc-sqlite3"
  gem "jdbc-mysql"
  gem "jdbc-postgres"
end
