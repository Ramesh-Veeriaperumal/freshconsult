class OnboardingDelegator < BaseDelegator
  validate :validate_domain_name, if: -> { @domain }
  validate :validate_trial_account, :validate_email_limit_for_account, on: :anonymous_to_trial

  def initialize(record, options = {})
    super(record, options)
    @domain = options[:new_domain]
    @email = options[:email]
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
end
