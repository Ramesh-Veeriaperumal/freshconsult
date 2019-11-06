module Mysql::RecordsHelper

  def delete_in_batches(account_id, table_name, batch_size = 50)
    return if account_id.blank? || table_name.blank?
    loop do
      yield if block_given?
      ids_of_records_to_delete = select_records_with_account_id(account_id, table_name, batch_size)
      delete_records_with_id(ids_of_records_to_delete, table_name)
      break if ids_of_records_to_delete.size < batch_size
    end
  end

  def delete_records_with_id(ids, table_name)
    return if ids.size.zero?
    delete_query = "delete from #{table_name} where id in (#{ids.join(',')})"
    ActiveRecord::Base.connection.execute(delete_query)
  end

  def select_records_with_account_id(account_id, table_name, batch_size = 50)
    query = "select id from #{table_name} where account_id = #{account_id} LIMIT #{batch_size}"
    ActiveRecord::Base.connection.select_values(query)
  end

  def delete_data_from_tables_with_composite_key(account_id, table_name, composite_key, batch_size = 50)
    return if account_id.blank? || composite_key.blank? || table_name.blank?
    loop do
      yield if block_given?
      records = select_records_with_composite_key(account_id, table_name, composite_key, batch_size)
      delete_records_with_composite_key(account_id, table_name, composite_key, records)
      break if records.size < batch_size
    end
  end

  def select_records_with_composite_key(account_id, table_name, composite_key, batch_size = 50)
    query = "select #{composite_key.join(',')} from #{table_name} where account_id = #{account_id} LIMIT #{batch_size}"
    ActiveRecord::Base.connection.select(query).map(&:values)
  end

  def delete_records_with_composite_key(account_id, table_name, composite_key, records)
    return if records.blank?
    in_clause = ""
    records.each do |entry|
      in_clause += "," if in_clause.present?
      in_clause += "(#{entry.join(",")})"
    end
    delete_query = "DELETE from #{table_name} where account_id = #{account_id} AND (#{composite_key.join(',')}) IN (#{in_clause})"
    ActiveRecord::Base.connection.execute(delete_query)
  end
end
