class Freshfone::UsageTrigger < ActiveRecord::Base
  self.primary_key = :id
  self.table_name =  :freshfone_usage_triggers
  
  attr_protected :account_id

  belongs_to_account
  belongs_to :freshfone_account, :class_name => "Freshfone::Account"

  TRIGGER_TYPE = { :credit_overdraft => 1, :daily_credit_threshold => 2, :calls_inbound => 3, :calls_outbound => 4 }
  TRIGGER_TYPE_BY_VALUE = TRIGGER_TYPE.invert

  TRIAL_TRIGGERS = [:calls_inbound, :calls_outbound]

  TRIGGER_DAILY_CREDIT_OPTIONS = { :trigger_type => :daily_credit_threshold,
    :usage_category => 'totalprice',
    :recurring => 'daily' }

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

  def daily_credit_threshold?
    trigger_type == :daily_credit_threshold
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
    Freshfone::UsageTrigger.create(
      :account => account,
      :freshfone_account => account.freshfone_account,
      :sid => trigger.sid,
      :trigger_type => attributes[:trigger_type].to_sym,
      :start_value => trigger.current_value.to_i,
      :trigger_value => trigger.trigger_value.to_i)
  end

  def self.create_daily_threshold_trigger(triggers, account_id)
    triggers.each do |_key, value|
      TRIGGER_DAILY_CREDIT_OPTIONS[:account_id] = account_id
      TRIGGER_DAILY_CREDIT_OPTIONS[:trigger_value] = value
      Resque.enqueue(Freshfone::Jobs::UsageTrigger, TRIGGER_DAILY_CREDIT_OPTIONS)
    end
  end

  def self.create_trial_call_usage_trigger(type, account_id, value)
    Resque.enqueue(Freshfone::Jobs::UsageTrigger,
      :account_id     => account_id,
      :trigger_type   => type,
      :usage_category => type.to_s.gsub('_', '-'),
      :trigger_value  => value)
  end

  def self.remove_daily_threshold_with_level(freshfone_account, level)
    return unless freshfone_account.present? && level.present?
    Freshfone::UsageTrigger.where(
      :account_id => freshfone_account.account.id,
      :freshfone_account_id => freshfone_account.id,
      :trigger_type => TRIGGER_TYPE[:daily_credit_threshold],
      :trigger_value => freshfone_account.triggers[level]).destroy_all
  end

  def self.update_triggers(freshfone_account, params)
    return unless freshfone_account.present? && params.present?

    usage_triggers = fetch_daily_threshold_with_freshfone(freshfone_account)

    usage_triggers.where('trigger_value NOT IN (?)',
      [params[:trigger_first].to_i, params[:trigger_second].to_i]).destroy_all

    freshfone_account.update_triggers(params)

    Freshfone::UsageTrigger.create_daily_threshold_trigger(
      find_new_triggers(freshfone_account, usage_triggers),
      freshfone_account.account.id)
  end

  def self.find_new_triggers(ff_acc, us_triggers)
    ff_acc.triggers.reject do |_k, v|
      us_triggers.any? do |tr|
        tr.trigger_value == v
      end
    end
  end

  def self.fetch_daily_threshold_with_freshfone(freshfone_account)
    Freshfone::UsageTrigger.where(
      :account_id => freshfone_account.account.id,
      :freshfone_account_id => freshfone_account.id,
      :trigger_type => TRIGGER_TYPE[:daily_credit_threshold])
  end

  def self.remove_calls_usage_triggers(freshfone_account, types = [TRIGGER_TYPE[:calls_inbound], TRIGGER_TYPE[:calls_outbound]])
    return if freshfone_account.blank?
    Freshfone::UsageTrigger.destroy_all(
      :account_id           => freshfone_account.account_id, 
      :freshfone_account_id => freshfone_account.id,
      :trigger_type         => types)
  end

  def self.fetch_triggers_by_type(types = [], freshfone_account)
    freshfone_account.freshfone_usage_triggers.where(:trigger_type => types) if freshfone_account.present?
  end

  def self.trial_triggers_present?(freshfone_account)
    self.fetch_triggers_by_type(TRIAL_TRIGGERS.map { |trigger| TRIGGER_TYPE[trigger] }, freshfone_account).present?
  end
end
