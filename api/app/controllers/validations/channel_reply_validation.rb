# frozen_string_literal: true

class ChannelReplyValidation < ApiValidation
  attr_accessor :body, :profile_unique_id, :channel_id, :attachment_ids

  validates :body, data_type: { rules: String, required: true, allow_nil: false }, if: -> { attachment_ids.blank? }
  validates :profile_unique_id, data_type: { rules: String, required: true, allow_nil: false }
  validates :channel_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param, required: true }

  def initialize(request_params, item = nil, allow_string_param = false)
    @item = item
    super
  end
end
