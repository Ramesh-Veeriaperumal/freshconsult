# frozen_string_literal: true

class ChannelReplyDelegator < ConversationBaseDelegator
  validate :validate_unseen_replies, on: :channel_reply, if: :traffic_cop_required?
end
