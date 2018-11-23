class GroupType < ActiveRecord::Base

  include GroupConstants

  self.table_name = :group_types
  self.primary_key = :id
  belongs_to_account

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id

  attr_accessible :name, :label, :default, :group_type_id, :deleted, :account_id

  after_commit :clear_group_types_cache

  def self.group_type_id(group_type_name)
    group_type = Account.current.group_types_from_cache.find{ |group_type| group_type.name == group_type_name }
    group_type ? group_type.group_type_id : nil
  end

  def self.label(group_type_name)
    group_type = Account.current.group_types.find_by_name(group_type_name)
    group_type ? group_type.label : nil
  end

  def self.group_type_name(group_type_id)
    group_type = Account.current.group_types.find_by_group_type_id(group_type_id)
    group_type ? group_type.name : nil
  end

  def self.populate_default_group_types(account)
    begin
      group_type = account.group_types.create(:name => SUPPORT_GROUP_NAME, :group_type_id => 1, 
        :label => SUPPORT_GROUP_NAME, :account_id => account.id, :deleted => false, :default => true)
      group_type.save!
    rescue Exception => e
      error_message = "Group type creation failed for account:: #{account.id}. Group type: #{SUPPORT_GROUP_NAME} Exception:: #{e.message} \n#{e.backtrace.to_a.join("\n")}"
      Rails.logger.error(error_message)
      NewRelic::Agent.notice_error(error_message)
    end



  end

  def self.destroy_group_type(account,group_type)
    account.group_types.find_by_name(group_type).destroy
  end  


  def clear_group_types_cache
    Account.current.clear_group_types_cache
  end
  
end
