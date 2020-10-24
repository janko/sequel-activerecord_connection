module Sequel
  module ActiveRecordConnection
    module Jdbc
      def self.extended(db)
        if db.timezone == :utc && db.respond_to?(:current_timestamp_utc)
          db.current_timestamp_utc = true
        end
      end

      def synchronize(*)
        super do |conn|
          yield conn.connection
        end
      end
    end
  end
end
