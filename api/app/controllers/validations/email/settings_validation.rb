class Email::SettingsValidation < ApiValidation
  include ActiveModel::Validations

  attr_accessor :allow_agent_to_initiate_conversation, :personalized_email_replies, :create_requester_using_reply_to, :original_sender_as_requester_for_forward

  validates :allow_agent_to_initiate_conversation, data_type: { rules: 'Boolean' }
  validates :personalized_email_replies, data_type: { rules: 'Boolean' }
  validates :create_requester_using_reply_to, data_type: { rules: 'Boolean' }
  validates :original_sender_as_requester_for_forward, data_type: { rules: 'Boolean' }
end
