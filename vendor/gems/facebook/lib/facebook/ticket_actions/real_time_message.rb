module Facebook
  module TicketActions
    module RealTimeMessage
      include Social::Util
      include Facebook::Util
      include Facebook::TicketActions::Util
      include Facebook::Constants

      FB_DM_TYPE = 'dm'.freeze

      def create_tickets(message, thread_key)
        fb_msg = latest_message(thread_key)
        previous_ticket = fb_msg.try(:postable)
        last_reply = if previous_ticket.present?
                       if previous_ticket.notes.present? && previous_ticket.notes.latest_facebook_message.present?
                         previous_ticket.notes.latest_facebook_message.first
                       else
                         previous_ticket
                       end
                     end
        if last_reply && (Time.zone.now < (last_reply.created_at + @fan_page.dm_thread_time.seconds))
          add_as_note(thread_key, message, previous_ticket)
        else
          add_as_ticket(thread_key, message)
        end

        if fb_msg.present? && fb_msg.thread_key.nil?
          @account.facebook_posts.where(thread_id: thread_key, facebook_page_id: @fan_page.id, thread_key: nil).find_each do |fb_post|
            fb_post.update_attributes(thread_key: thread_key)
          end
        end
      end

      private

        def add_as_note(thread_key, message, ticket)
          message = message.deep_symbolize_keys
          return if @account.facebook_posts.exists?(post_id: message[:id])

          user = facebook_user(message[:from])
          is_page_message = is_a_page?(message[:from], @fan_page.page_id)
          fb_note_properties = {
            private: true,
            incoming: !is_page_message,
            source: Helpdesk::Source.note_source_keys_by_token['facebook'],
            account_id: @fan_page.account_id,
            user: user,
            created_at: Time.zone.parse(message[:created_time]),
            fb_post_attributes: {
              post_id: message[:id],
              facebook_page_id: @fan_page.id,
              account_id: @account.id,
              msg_type: FB_DM_TYPE,
              thread_id: thread_key,
              thread_key: thread_key
            }
          }
          @note = ticket.notes.build(fb_note_properties)
          body_html = html_content_from_message(message, @note)
          @note.note_body_attributes = {
            body_html: body_html
          }

          @note.build_schema_less_note.category = Helpdesk::Note::CATEGORIES[:third_party_response] if is_page_message

          begin
            user.make_current
            Rails.logger.debug "Error occurred while saving the note for account: #{@account.id} page: #{@fan_page.page_id} message: #{message.inspect} error: #{@note.errors.to_json}" unless @note.save_note
          ensure
            User.reset_current_user
          end
        end

        def add_as_ticket(thread_key, message)
          message = message.deep_symbolize_keys
          group_id = @fan_page.dm_stream.ticket_rules.first.group_id

          return if !message || @account.facebook_posts.exists?(post_id: message[:id])

          is_page_message = is_a_page?(message[:from], @fan_page.page_id)

          requester = is_page_message ? facebook_user(message[:to][:data].first) : facebook_user(message[:from])
          ticket_subject = construct_fb_page_message_subject(message, is_page_message, requester)
          fb_ticket_properties = {
            subject: ticket_subject,
            requester: requester,
            product_id: @fan_page.product_id,
            group_id: group_id,
            source: Helpdesk::Source::FACEBOOK,
            created_at: Time.zone.parse(message[:created_time]),
            fb_post_attributes: {
              post_id: message[:id],
              facebook_page_id: @fan_page.id,
              account_id: @account.id,
              msg_type: FB_DM_TYPE,
              thread_id: thread_key,
              thread_key: thread_key
            }
          }
          @ticket = @account.tickets.build(fb_ticket_properties)
          description_html = html_content_from_message(message, @ticket)
          @ticket.ticket_body_attributes = {
            description_html: description_html
          }

          Rails.logger.debug "Error while saving the fb ticket for account: #{@account.id} page: #{@fan_page.page_id} message: #{message.inspect} error: #{@ticket.errors.to_json}" unless @ticket.save_ticket
        end

        def construct_fb_page_message_subject(message, is_page_message, requester)
          from_name, to_name = is_page_message ? [@fan_page.page_name, requester.name] : [requester.name, @fan_page.page_name]
          generic_subject = I18n.t('facebook.page_message_subject', from_name: from_name, to_name: to_name)
          if message[:message].present?
            ticket_subject = truncate_subject(tokenize(message[:message]), 100)
            ticket_subject = "#{generic_subject} : #{ticket_subject}" if is_page_message
            return ticket_subject
          end

          generic_subject
        end
    end
  end
end