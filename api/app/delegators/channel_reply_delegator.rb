class ChannelReplyDelegator < ConversationBaseDelegator
  validate :validate_unseen_replies, on: :tweet, if: :traffic_cop_required?
end