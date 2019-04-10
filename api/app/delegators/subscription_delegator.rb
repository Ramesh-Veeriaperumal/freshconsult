class SubscriptionDelegator < BaseDelegator
  validate :validate_user_id, if: :user_id

  def initialize(record, _options = {})
    super(record)
  end

  def validate_user_id
    user_exists = Account.current.users.exists?(id: user_id, helpdesk_agent: true)
    errors[:user_id] << :"is invalid" unless user_exists
  end
end
