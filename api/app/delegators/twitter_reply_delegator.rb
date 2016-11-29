class TwitterReplyDelegator < BaseDelegator
  attr_accessor :twitter_handle_id

  validate :validate_twitter_handle

  validate :validate_agent_id, if: -> { fwd_email? && user_id.present? && attr_changed?('user_id') }

  def initialize(record, options = {})
    super(record, options)
    @twitter_handle_id = options[:twitter_handle_id]
  end

  def validate_twitter_handle
    twitter_handle = Account.current.twitter_handles.where(id: @twitter_handle_id).first
    errors[:twitter_handle_id] << :"is invalid" unless twitter_handle
  end

  def validate_agent_id
    user = Account.current.agents_details_from_cache.find { |x| x.id == user_id }
    errors[:agent_id] << :"is invalid" unless user
  end
end
