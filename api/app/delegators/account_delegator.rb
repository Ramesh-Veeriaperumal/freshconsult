class AccountDelegator < BaseDelegator
  
  validate :validate_account_suspended, on: :cancel
  
  def initialize(record, options = {})
    super(record, options)
  end
  
  def validate_account_suspended
    errors[:account_cancel] << 'Account already suspended.' if Account.current.suspended?
  end
end