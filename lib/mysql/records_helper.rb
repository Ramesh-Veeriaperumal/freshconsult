module Mysql::RecordsHelper

  def delete_in_batches(account_id, table_name, batch_size = 10)
    return if account_id.blank? || table_name.blank?
    loop do
      yield if block_given?
      ids_of_records_to_delete = select_records_with_account_id(account_id, table_name, batch_size)
      delete_records_with_id(ids_of_records_to_delete, account_id, table_name)
      break if ids_of_records_to_delete.size < batch_size
    end
  end

  def delete_records_with_id(ids, account_id, table_name)
    return if ids.size.zero? || account_id.blank? || table_name.blank?

    delete_query = ['delete from %s where account_id = %s AND id in (%s);', table_name, account_id, ids.join(',')]
    sanitized_delete_query = ActiveRecord::Base.safe_send(:sanitize_sql_array, delete_query)
    ActiveRecord::Base.connection.execute(sanitized_delete_query)
  end

  def select_records_with_account_id(account_id, table_name, batch_size = 10)
    select_query = ['select id from %s where account_id = %s LIMIT %s;', table_name, account_id, batch_size]
    sanitized_select_query = ActiveRecord::Base.safe_send(:sanitize_sql_array, select_query)
    ActiveRecord::Base.connection.select_values(sanitized_select_query)
  end

  def delete_data_from_tables_with_composite_key(account_id, table_name, composite_key, batch_size = 10)
    return if account_id.blank? || composite_key.blank? || table_name.blank?
    loop do
      yield if block_given?
      records = select_records_with_composite_key(account_id, table_name, composite_key, batch_size)
      delete_records_with_composite_key(account_id, table_name, composite_key, records)
      break if records.size < batch_size
    end
  end

  def select_records_with_composite_key(account_id, table_name, composite_key, batch_size = 10)
    select_query = ['select %s from %s where account_id = %s LIMIT %s;', composite_key.join(','), table_name, account_id, batch_size]
    sanitized_select_query = ActiveRecord::Base.safe_send(:sanitize_sql_array, select_query)
    ActiveRecord::Base.connection.select(sanitized_select_query).map(&:values)
  end

  def delete_records_with_composite_key(account_id, table_name, composite_key, records)
    return if records.blank?
    in_clause = ""
    records.each do |entry|
      in_clause += "," if in_clause.present?
      in_clause += "(#{entry.join(",")})"
    end
    delete_query = ['delete from %s where account_id = %s AND (%s) in (%s);', table_name, account_id, composite_key.join(','), in_clause]
    sanitized_delete_query = ActiveRecord::Base.safe_send(:sanitize_sql_array, delete_query)
    ActiveRecord::Base.connection.execute(sanitized_delete_query)
  end
end
