class SubscriptionDelegator < BaseDelegator
  validate :validate_user_id, if: :user_id

  def initialize(record, options = {})
    super(record)
  end

  def validate_user_id
    user = Account.current.agents_from_cache.detect { |x| user_id == x.user_id }
    errors[:user_id] << :"is invalid" unless user
  end
end
