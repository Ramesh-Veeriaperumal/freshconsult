module Sync::SqlUtil
  include Sync::Constants
  
  def delete_and_insert(table_name, id, arel_values)
    #delete the record
    #delete_record(table_name, id) commenting out because we clear all the data from the tables before we start the sync.

    table   = Arel::Table.new(table_name.to_sym)

    manager = Arel::InsertManager.new(ActiveRecord::Base)
    manager.into(table)
    manager.insert(arel_values)
    sql = manager.to_sql

    #puts sql
    insert_id = ActiveRecord::Base.connection.insert(sql)
    #puts "*"*100
    
    if !id.zero? 
      return insert_id
    end
    return nil
  end

  def delete_record(table_name, id)
    sql = "DELETE from #{table_name} where id = #{id}"
    #puts sql
    ActiveRecord::Base.connection.execute(sql)
  end

  def record_present?(table_name, id)
    sql = "select (1) from #{table_name} where id = #{id}"
    #puts sql
    !ActiveRecord::Base.connection.execute(sql).to_a.blank?
  end
end
