class GroupType < ActiveRecord::Base

  include GroupConstants

  # name, label, and group_type_id
  # If we need to create custom group types, we need to offset group_type_id to some higervalues, so that we can have our default types without collision.
  DEFAULT_GROUP_TYPE_LIST = {
    support_agent_group: [:support_agent_group, 'support_agent_group', 1],
    field_agent_group: [:field_agent_group, 'field_agent_group', 2]
  }.freeze

  # not meant to be used outside of this class. use group_type_id instead
  DEFAULT_GROUP_TYPE_NAME_VS_GROUP_TYPE_ID = Hash[DEFAULT_GROUP_TYPE_LIST.values.map { |detail| [detail[0], detail[2]] }].freeze
  DEFAULT_GROUP_TYPE_ID_VS_GROUP_TYPE_NAME = Hash[DEFAULT_GROUP_TYPE_LIST.values.map { |detail| [detail[2], detail[0]] }].freeze
  private_constant :DEFAULT_GROUP_TYPE_NAME_VS_GROUP_TYPE_ID, :DEFAULT_GROUP_TYPE_LIST, :DEFAULT_GROUP_TYPE_ID_VS_GROUP_TYPE_NAME

  self.table_name = :group_types
  self.primary_key = :id
  belongs_to_account

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id

  attr_accessible :name, :label, :default, :group_type_id, :deleted, :account_id

  after_commit :clear_group_types_cache

  def self.group_type_id(group_type_name)
    return DEFAULT_GROUP_TYPE_NAME_VS_GROUP_TYPE_ID[group_type_name.to_sym] if group_type_name && DEFAULT_GROUP_TYPE_NAME_VS_GROUP_TYPE_ID.key?(group_type_name.to_sym)

    group_type = Account.current.group_types_from_cache.find{ |group_type| group_type.name == group_type_name.to_s }
    group_type ? group_type.group_type_id : nil
  end

  def self.group_type_name(group_type_id)
    return DEFAULT_GROUP_TYPE_ID_VS_GROUP_TYPE_NAME[group_type_id].to_s if DEFAULT_GROUP_TYPE_ID_VS_GROUP_TYPE_NAME.key?(group_type_id)

    group_type = Account.current.group_types.find_by_group_type_id(group_type_id)
    group_type ? group_type.name : nil
  end

  def self.populate_default_group_types(account)
    begin
      group_type = GroupType.create_group_type(account,SUPPORT_GROUP_NAME)
      group_type
    rescue Exception => e
      error_message = "Group type creation failed for account:: #{account.id}. Group type: #{SUPPORT_GROUP_NAME} Exception:: #{e.message} \n#{e.backtrace.to_a.join("\n")}"
      Rails.logger.error(error_message)
      NewRelic::Agent.notice_error(error_message)
    end
  end

  def self.create_group_type(account,group_type)
    group_type = group_type.to_sym
    group_type_details = DEFAULT_GROUP_TYPE_LIST[group_type]

    raise "Invalid group type #{group_type}" unless group_type_details

    create_group_type_with(group_type_details, account)
  end

  def self.destroy_group_type(account,group_type)
    group_type_record = account.group_types.find_by_name(group_type)
    group_type_id = group_type_record.try(:group_type_id)
    group_type_record.try(:destroy)
    account.groups.where(group_type: group_type_id).destroy_all if group_type_id
  end  

  def clear_group_types_cache
    Account.current.clear_group_types_cache
  end

  def self.create_group_type_with(group_type_details, account)
    group_type = account.group_types.create(
      name: group_type_details[0],
      label: group_type_details[1],
      account_id: account.id,
      deleted: false,
      default: true,
      group_type_id: group_type_details[2]
    )
    group_type.save!
    group_type
  rescue Exception => e # rubocop:disable RescueException
    error_message = "Group type creation failed for account:: #{account.id}. Group type: #{group_type_details.join(', ')} Exception:: #{e.message} \n#{e.backtrace.to_a.join("\n")}"
    Rails.logger.error(error_message)
    NewRelic::Agent.notice_error(error_message)
  end
  private_class_method :create_group_type_with
end
