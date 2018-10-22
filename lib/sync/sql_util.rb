module Sync::SqlUtil
  include Sync::Constants

  def delete_and_insert(table_name, id, arel_values)
    table = Arel::Table.new(table_name.to_sym)

    manager = Arel::InsertManager.new(ActiveRecord::Base)
    manager.into(table)
    manager.insert(arel_values)
    sql = manager.to_sql

    insert_id = ActiveRecord::Base.connection.insert(sql)

    return insert_id unless id.zero?
    nil
  end

  def delete_record(table_name, id)
    sql = "DELETE from #{table_name} where id = #{id}"
    ActiveRecord::Base.connection.execute(sql)
  end

  def record_present?(table_name, account_id, id, object)
    sql = "select (1) from #{table_name} where id = #{id} and account_id = #{account_id}"
    sql += " and deleted = 0" if object.respond_to?('deleted') # soft delete
    ActiveRecord::Base.connection.execute(sql).to_a.present?
  end

  def delete_habtm_record(table_name, arel_values)
    sql = "DELETE from #{table_name} where #{habtm_condition(arel_values)}"
    ActiveRecord::Base.connection.execute(sql)
  end

  def habtm_condition(arel_values)
    arel_values.map{ |value| "#{value[0].name.to_s} = #{value[1]}"}.join(" and ")
  end
end
