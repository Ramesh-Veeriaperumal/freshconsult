class TwitterReplyDelegator < ConversationBaseDelegator
  include Redis::OthersRedis
  include Redis::RedisKeys

  attr_accessor :twitter_handle_id

  validate :validate_twitter_handle, :check_twitter_app_state
  validate :validate_agent_id, if: -> { fwd_email? && user_id.present? && attr_changed?('user_id') }
  validate :validate_unseen_replies, on: :tweet, if: :traffic_cop_required?

  def initialize(record, options = {})
    super(record, options)
    @twitter_handle_id = options[:twitter_handle_id]
  end

  def validate_twitter_handle
    twitter_handle = Account.current.twitter_handles.where(id: @twitter_handle_id).first
    return errors[:twitter_handle_id] << :"is invalid" unless twitter_handle
    errors[:twitter_handle_id] << :"requires re-authorization" if twitter_handle.reauth_required?
  end

  def check_twitter_app_state
    errors[:twitter] << :twitter_write_access_blocked if redis_key_exists?(TWITTER_APP_BLOCKED)
  end

  def validate_agent_id
    user = Account.current.agents_details_from_cache.find { |x| x.id == user_id }
    errors[:agent_id] << :"is invalid" unless user
  end
end
