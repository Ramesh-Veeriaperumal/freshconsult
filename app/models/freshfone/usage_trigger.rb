class Freshfone::UsageTrigger < ActiveRecord::Base
  self.primary_key = :id
  self.table_name =  :freshfone_usage_triggers
  
  attr_protected :account_id

  belongs_to_account
  belongs_to :freshfone_account, :class_name => "Freshfone::Account"

  TRIGGER_TYPE = { :credit_overdraft => 1, :daily_credit_threshold => 2 }
  TRIGGER_TYPE_BY_VALUE = TRIGGER_TYPE.invert

  scope :previous, lambda { |type| { 
    :conditions => ["trigger_type = ?", Freshfone::UsageTrigger::TRIGGER_TYPE[type.to_sym]], 
    :limit => 1,
    :order => "created_at DESC" } }

  def trigger_type
    TRIGGER_TYPE_BY_VALUE[read_attribute(:trigger_type)]
  end
 
  def trigger_type=(t)
    write_attribute(:trigger_type, TRIGGER_TYPE[t])
  end

  def update_trigger options
    return false if options.blank?
    update_attributes({ :fired_value => options[:CurrentValue].to_i, 
                        :idempotency_token => options[:IdempotencyToken] }) 
  end

  def self.create_trigger(account, attributes)
    #@twilio
    trigger = account.freshfone_subaccount.usage.triggers.create(
      :friendly_name => attributes[:trigger_type],
      :usage_category => attributes[:usage_category],
      :callback_url => "#{account.full_url}/freshfone/usage_triggers/notify",
      :recurring => attributes[:recurring],
      :trigger_value => attributes[:trigger_value])

    #@model
    account.freshfone_account.freshfone_usage_triggers.create(
      :freshfone_account => account.freshfone_account,
      :sid => trigger.sid,
      :trigger_type => attributes[:trigger_type].to_sym,
      :start_value => trigger.current_value.to_i,
      :trigger_value => trigger.trigger_value.to_i)
  end

end
