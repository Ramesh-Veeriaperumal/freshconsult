class Va::Handlers::DateTime < Va::RuleHandler
  def filter_query_less_than
    [ "#{condition.db_column} > ?", value.to_i.hours.ago.to_s(:db) ]
  end
  
  def filter_query_greater_than
    [ "#{condition.db_column} < ?", value.to_i.hours.ago.to_s(:db) ]
  end
end
