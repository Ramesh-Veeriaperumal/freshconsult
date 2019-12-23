class UpdateSQLParser
  include ActiverecordLogConstants
  def initialize
    @quote_char = "'"
  end

  def read_column_name(update_clause)
    # Read the part "`<column_name>`"
    end_index = update_clause[0] == '`' ? update_clause.index('`', 1) : update_clause.index(' = ') - 1
    update_clause.slice!(0..end_index)
  end

  def read_unquoted_value(update_clause)
    end_index = update_clause.index(', ')
    if end_index.nil?
      update_clause.slice!(0..-1)
    else
      update_clause.slice!(0..end_index - 1)
    end
  end

  def count_preceding_backslashes(update_clause, end_index)
    count = 0
    count += 1 while update_clause[end_index - count - 1] == '\\'
    count
  end

  def read_quoted_value(update_clause)
    start = 1
    loop do
      end_index = update_clause.index("'", start)
      if end_index.nil?
        raise MalformedSqlError "Missing or stray quote at #{update_clause}"
      elsif update_clause[end_index - 1] == '\\'
        backslashes = count_preceding_backslashes(update_clause, end_index)
        if (backslashes % 2).zero?
          return update_clause.slice!(0..end_index)
        else
          start = end_index + 1
        end
      else
        return update_clause.slice!(0..end_index)
      end
    end
  end

  def read_value(update_clause)
    # " = '" <value> "'" | " = " <value>
    update_clause.slice!(0, ' = '.size)
    if update_clause[0] == @quote_char
      read_quoted_value(update_clause)
    else
      read_unquoted_value(update_clause)
    end
  end

  def udpate_clause_parse(update_clause)
    result = {}
    loop do
      col_name = read_column_name(update_clause)
      value = read_value(update_clause)
      result[col_name] = value
      break if update_clause.empty?

      update_clause.slice!(0..', '.size - 1) # Remove ", " before next key=value pair
    end
    result
  end

  def parse_update_sql_query(sql)
    query = sql.slice(UPDATE_QUERY_SIZE, sql.size)
    table_name, query = query.split('`', 2)
    if COLUMN_MODEL_NAME_HASH.key?(table_name.to_sym)
      _, query = query.split(' SET ')
      values, _, remaining_part = query.rpartition(' WHERE ')
      values = udpate_clause_parse(values.strip)
      splitted_arr = [table_name, values, remaining_part]
      Rails.logger.info "Skipping filtering confidential logs for update, unexpected size of parsed sql array Request_id :: #{request_id}" unless splitted_arr.compact.size == 3
      splitted_arr
    else
      []
    end
  end
end

class MalformedSqlError < RuntimeError
end
