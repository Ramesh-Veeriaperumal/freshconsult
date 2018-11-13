class AccountDelegator < BaseDelegator
  
  validate :validate_account_cancellation_requested, :validate_account_suspended, on: :cancel
  
  def initialize(record, options = {})
    super(record, options)
  end
  
  def validate_account_cancellation_requested
      errors[:account_cancel] << 'Account Cancellation already requested.' if Account.current.account_cancellation_requested?
  end
  
  def validate_account_suspended
      errors[:account_cancel] << 'Account already suspended.' if Account.current.suspended?
  end
  
end