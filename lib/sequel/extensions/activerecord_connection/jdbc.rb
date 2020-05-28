module Sequel
  module ActiveRecordConnection
    module Jdbc
      def statement(conn)
        stmt = conn.connection.createStatement
        yield stmt
      rescue *DATABASE_ERROR_CLASSES => e
        raise_error(e)
      ensure
        stmt.close if stmt
      end
    end
  end
end