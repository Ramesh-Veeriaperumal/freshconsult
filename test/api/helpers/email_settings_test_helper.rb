module EmailSettingsTestHelper
  def all_features_params
    {
      'personalized_email_replies': true,
      'create_requester_using_reply_to': true,
      'allow_agent_to_initiate_conversation': true,
      'original_sender_as_requester_for_forward': true,
      'skip_ticket_threading': true,
      'allow_wildcard_ticket_create': true,
      'threading_without_user_check': true
    }
  end

  def invalid_field_params
    {
      'invalid_field': true
    }
  end
end
