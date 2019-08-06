class Va::Handlers::DateTimeStatus < Va::Handlers::DateTime
  def filter_query_is
    return [false] unless Account.current.launched? :supervisor_custom_status

    ["round((unix_timestamp(UTC_TIMESTAMP()) - unix_timestamp(#{condition.db_column[0]}))/3600) = ? and  #{condition.db_column[1]} = ?",
    value.to_i, fetch_custom_status_id]
  end

  def filter_query_less_than
    return [false] unless Account.current.launched? :supervisor_custom_status

    ["#{condition.db_column[0]} > ? and #{condition.db_column[1]} = ?", value.to_i.hours.ago.to_s(:db), fetch_custom_status_id]
  end

  def filter_query_greater_than
    return [false] unless Account.current.launched? :supervisor_custom_status

    ["#{condition.db_column[0]} < ? and #{condition.db_column[1]} = ?", value.to_i.hours.ago.to_s(:db), fetch_custom_status_id]
  end

  private

    def during(evaluated_on_value)
      safe_send(value, evaluated_on_value)
    end

    def fetch_custom_status_id
      @rule_hash[:name].split('_').last.to_i
    end
end
