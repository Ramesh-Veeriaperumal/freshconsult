require_relative '../../../lib/redis/others_redis'
class OnboardingDelegator < BaseDelegator
  include OnboardingConstants
  include Redis::OthersRedis
  
  validate :validate_domain_name, if: -> { @domain }
  validate :validate_trial_account, on: :anonymous_to_trial
  validate :validate_email_limit_for_account, on: :anonymous_to_trial, :if => :whitelisted_email?
  validate :validate_freshchat_account_availability, on: :update_channel_config, if: -> { @channel == FRESHCHAT }
  validate :validate_freshcaller_account_availability, on: :update_channel_config, if: -> { @channel == FRESHCALLER }

  def initialize(record, options = {})
    super(record, options)
    @domain = options[:new_domain]
    @email = options[:email]
    @channel = options[:channel]
  end
  
  def whitelisted_email?
    !ismember?(INCREASE_DOMAIN_FOR_EMAILS, @email)
  end
    
  def validate_domain_name
    errors[:domain] << :invalid_domain unless DomainGenerator.valid_domain?(@domain)
  end

  def validate_trial_account
    errors[:anonymous_to_trial] << :account_in_trial unless Account.current.anonymous_account?
  end

  def validate_email_limit_for_account
    accounts_count = AdminEmail::AssociatedAccounts.find(@email).length
    if accounts_count >= Signup::MAX_ACCOUNTS_COUNT
      errors[:anonymous_to_trial] << :email_limit_reached
      error_options[:anonymous_to_trial] = { limit: Signup::MAX_ACCOUNTS_COUNT }
    end
  end

  def validate_freshchat_account_availability
    if Account.current.freshchat_account.present?
      errors[:channel] << :channel_already_present
      error_options[:channel] = { channel_name: 'Freshchat' }
    end
  end

  def validate_freshcaller_account_availability
    if Account.current.freshcaller_account.present?
      errors[:channel] << :channel_already_present
      error_options[:channel] = { channel_name: 'Freshcaller' }
    end
  end
end
