class Helpdesk::Mysql::DynamicTable < ActiveRecord::Base
  self.abstract_class = true
  def self.create(table_name, options={})
    self.table_name = table_name
    id = options.delete(:id)
    conditions = options.delete(:conditions)
    super(options)
  end

  def self.create_or_update(table_name,options = {})
    self.table_name = table_name
    id = options.delete(:id)
    conditions = options.delete(:conditions)

    record = id ? find_by_id(id) : find(:first, :conditions => conditions) || new

    options.each_pair { |key, value| record[key] = value }
    record.save!
    record
  end
end