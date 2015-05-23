class QueryCounter
  cattr_accessor :total_query_count do
    0
  end

  cattr_accessor :api_query_count do
    0
  end

  IGNORED_SQL = [/SHOW/]
  API_SQL = /api/

  def call(name, start, finish, message_id, values)
    unless 'CACHE' == values[:name]
      unless IGNORED_SQL.any? { |r| values[:sql] =~ r }
        self.class.total_query_count += 1 
        self.class.api_query_count += 1 if values[:filename] =~ API_SQL
      end
    end
  end
end

ActiveSupport::Notifications.subscribe('sql.active_record', QueryCounter.new)
