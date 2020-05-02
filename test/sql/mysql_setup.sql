CREATE USER 'sequel_activerecord_connection'@'localhost' IDENTIFIED BY 'sequel_activerecord_connection';
CREATE DATABASE sequel_activerecord_connection;
GRANT ALL ON sequel_activerecord_connection.* TO 'sequel_activerecord_connection'@'localhost' WITH GRANT OPTION;
