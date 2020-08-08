# This model is for only monthly tables
class Helpdesk::Mysql::DynamicTable < ActiveRecord::Base

  self.abstract_class = true
  TABLE_NAME = {
    "Helpdesk::SpamTicket" => "spam_tickets",
    "Helpdesk::SpamNote" => "spam_notes"
  }
  
  def self.create(options={})
    determine_table_name
    super(options)
  end

  def self.find_by_id(id)
    determine_table_name
    super(id)
  end

  def self.find_by_id_and_account_id(id, account_id)
    # self.table_name = Helpdesk::Mysql::Util.table_name_extension_monthly(table_name)
    determine_table_name
    super(id,account_id)
  end

  def self.find_all(options)
    determine_table_name
    where(options[:conditions]).order(options[:order]).limit(options[:limit])
  end

  def self.destroy_all(options)
    determine_table_name
    super(options)
  end

  def self.determine_table_name
    self.table_name = Helpdesk::Mysql::Util.table_name_extension_monthly(TABLE_NAME[self.to_s])
  end
end