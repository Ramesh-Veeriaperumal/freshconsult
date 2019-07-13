module Facebook::TicketActions::CentralUtil
  include ChannelIntegrations::Utils::Schema

  STATUS_UPDATE_COMMAND_NAME = 'update_facebook_reply_state'.freeze
  OWNER = 'facebook'.freeze

  def post_success_or_failure_command(args)
    is_success = args[:error_msg].blank? && args[:error_code].blank?
    command_payload = construct_payload(args, is_success)
    msg_id = Social::Util.generate_msg_id(command_payload)
    ::Rails.logger.info("Command from Facebook, command: #{STATUS_UPDATE_COMMAND_NAME}, msg_id: #{msg_id}")
    Channel::CommandWorker.perform_async(
      {
        override_payload_type: ChannelIntegrations::Constants::PAYLOAD_TYPES[:command_to_helpkit],
        payload: command_payload
      }, msg_id
    )
  end

  def construct_payload(args, is_success)
    payload = default_command_schema('helpkit', STATUS_UPDATE_COMMAND_NAME)
    payload[:owner] = OWNER
    payload[:data] = construct_base_data_hash(is_success)
    if is_success
      payload[:data][:details] = construct_success_hash(args[:fb_post_id])
    else
      payload[:data][:error] = construct_data_error_hash(args[:error_msg], args[:error_code])
    end
    payload[:context] = build_context_hash(args[:note_id],
                                           args[:note_created_at],
                                           args[:msg_type],
                                           args[:fb_page_id])
    payload
  end

  def construct_base_data_hash(is_success)
    {
      success: is_success
    }
  end

  def construct_success_hash(fb_item_id)
    {
      facebook_item_id: fb_item_id,
      posted_at: Time.now.utc
    }
  end

  def construct_data_error_hash(error_msg, error_code)
    {
      error_code: error_code,
      error_message: error_msg
    }
  end

  def build_context_hash(note_id, note_created_at, msg_type, fb_page_id)
    {
      note: {
        id: note_id,
        created_at: note_created_at
      },
      facebook_data: {
        event_type: msg_type,
        facebook_page_id: fb_page_id
      }
    }
  end
end
