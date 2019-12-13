module ChannelIntegrations::Commands::Services

  class UserNotFoundException < StandardError
  end

  class Facebook
    include ChannelIntegrations::Utils::ActionParser
    include Social::FB::Util
    include ChannelIntegrations::CommonActions::Ticket
    include ChannelIntegrations::CommonActions::Note

    def receive_update_facebook_reply_state(payload)
      return unless Account.current.launched?(:skip_posting_to_fb)

      context = payload[:context]
      data = payload[:data]

      return error_message('Invalid request') unless validate_request?(context, data)

      if data[:success]
        return error_message('Facebook item id cannot be empty') if data.try(:[], :details).try(:[], :facebook_item_id).blank?

        fb_post = current_account.facebook_posts.fetch_postable(context[:note][:id]).first

        return error_message('Facebook post record not found') if fb_post.blank?

        update_fb_post(fb_post, data)
      else
        note_id = context[:note][:id]
        schema_less_note = current_account.schema_less_notes.find_by_note_id(note_id)

        return error_message('SchemaLessNote not found') if schema_less_note.blank?

        update_facebook_errors_in_schemaless_note(schema_less_note, data)
        notify_iris(note_id)
      end

      default_success_format
    rescue StandardError => e
      Rails.logger.error "Something went wrong in update_facebook_reply_state account_id: #{current_account.id}, context: #{context.inspect} e_message: #{e.message}"
      error_message("Error in update_facebook_reply_state, account_id: #{current_account.id}, context: #{context.inspect}")
    end

    def receive_create_ticket(payload)
      context = payload[:context]
      create_ticket_payload = validate_and_build_command_payload(payload, true)
      ticket = create_ticket(create_ticket_payload)
      Rails.logger.info("Ticket created for #{context.inspect} :: Account ID : #{payload[:account_id]}")
      ticket
    rescue StandardError => e
      Rails.logger.error("Error creating #{context.inspect} ticket :: #{e.message}")
      error_message("Error in creating ticket, account_id: #{current_account.id}, context: #{context.inspect}, error:
 #{e.message}")
    end

    def receive_create_note(payload)
      context = payload[:context]
      create_note_payload = validate_and_build_command_payload(payload, false)
      note = create_note(create_note_payload)
      Rails.logger.info("Facebook::CreateNote, account_id: #{current_account.id}, post_id: #{context[:post_id]}")
      note
    rescue StandardError => e
      Rails.logger.error "Something wrong in Facebook::CreateNote account_id: #{current_account.id}, context: #{context
                                                                                                             .inspect} #{e.message}"
      error_message("Error in Creating note, account_id: #{current_account.id}, context: #{context.inspect}, error:
#{e.message}")
    end

    private

      def validate_and_build_command_payload(payload, is_ticket = true)
        raise 'Invalid request' unless check_ticket_params?(payload)

        user_id = is_ticket ? payload[:data][:requester_id] : payload[:data][:user_id]
        set_current_user(user_id)
        facebook_page_present?(payload[:context][:facebook_page_id])
        payload[:data].merge!(get_source_hash(payload[:owner], is_ticket))
        payload[:data][:fb_post_attributes] = build_fb_post_attributes(payload, is_ticket)
        payload
      end

      def error_message(message)
        error = default_error_format
        error[:data] = { message: message }
        error
      end

      def validate_request?(context, data)
        context.present? && context.try(:[], :note).try(:[], :id).present? && data.present?
      end

      def update_fb_post(fb_post, data)
        fb_post.post_id = data[:details][:facebook_item_id]
        fb_post.save!
      end

      def update_facebook_errors_in_schemaless_note(schema_less_note, data)
        schema_less_note.note_properties[:errors] ||= {}
        fb_errors = { facebook: { error_code: data[:errors][:error_code], error_message: data[:errors][:error_message] } }
        schema_less_note.note_properties[:errors].merge!(fb_errors)
        schema_less_note.save!
      end

      def set_current_user(requester_id)
        user = requester_id ? current_account.users.find(requester_id) : nil
        raise UserNotFoundException, 'User not found' if user.blank?

        user.make_current
      end

      def facebook_page_present?(page_id)
        raise 'Facebook Page Not found' if current_account.facebook_pages.find_by_page_id(page_id).blank?
      end

      def get_source_hash(owner, is_ticket)
        { source: if is_ticket
                    TicketConstants::SOURCE_KEYS_BY_TOKEN[owner.to_sym]
                  else
                    Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[owner]
                  end }
      end

      def build_fb_post_attributes(payload, is_ticket=true)
        context = payload[:context]
        fb_post_types = ::Facebook::Constants::POST_TYPE_CODE
        if is_ticket
          post_type = fb_post_types[:comment]
          parent_id = nil
        else
          post_type = fb_post_types[:reply_to_comment]
          parent_id = current_account.tickets.find_by_display_id(payload[:data][:ticket_id]).fb_post.id
        end

        {
            :post_id          => context[:post_id],
            :facebook_page_id => context[:facebook_page_id],
            :parent_id        => parent_id,
            :post_attributes  => {
                :can_comment => true,
                :post_type   => post_type
            }
        }
      end

      def check_ticket_params?(payload)
        context = payload[:context]
        context[:post_id] && base_validation?(context)
      end

      def base_validation?(context)
        context[:post_type] && context[:facebook_page_id] # && context[:stream_id] Will be added after adpost stream changes are done
      end
  end
end
