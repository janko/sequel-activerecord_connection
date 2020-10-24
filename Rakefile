require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = true
end

task default: :test

desc "Setup database used for testing on PostgreSQL"
task :db_setup_postgres do
  sh 'psql -U postgres -c "CREATE USER sequel_activerecord_connection PASSWORD \'sequel_activerecord_connection\'"'
  sh 'createdb -U postgres -O sequel_activerecord_connection sequel_activerecord_connection'
end

desc "Teardown database used for testing on PostgreSQL"
task :db_teardown_postgres do
  sh 'dropdb -U postgres sequel_activerecord_connection'
  sh 'dropuser -U postgres sequel_activerecord_connection'
end

desc "Setup database used for testing on MySQL"
task :db_setup_mysql do
  sh 'mysql -u root -p mysql < test/sql/mysql_setup.sql'
end

desc "Teardown database used for testing on MySQL"
task :db_teardown_mysql do
  sh 'mysql -u root -p mysql < test/sql/mysql_teardown.sql'
end
