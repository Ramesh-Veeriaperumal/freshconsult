class QueryCounter
  cattr_accessor :total_query_count do
    0
  end

  cattr_accessor :api_query_count do
    0
  end

  cattr_accessor :queries do
    []
  end

  IGNORED_SQL = [/SHOW/]
  API_SQL = /\/api\//
  IGNORE_TEST_API_SQL = /^((?!test\/api).)*$/

  def call(_name, _start, _finish, _message_id, values)
    unless 'CACHE' == values[:name]
      unless IGNORED_SQL.any? { |r| values[:sql] =~ r }
        self.class.queries << values[:sql]
        self.class.total_query_count += 1
        self.class.api_query_count += 1 if values[:filename] =~ API_SQL && values[:filename] =~ IGNORE_TEST_API_SQL
      end
    end
  end
end

ActiveSupport::Notifications.subscribe('sql.active_record', QueryCounter.new)
