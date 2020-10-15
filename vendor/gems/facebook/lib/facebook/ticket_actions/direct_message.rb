module Facebook
  module TicketActions
    module DirectMessage
      include Social::Util
      include Facebook::Util
      include Facebook::TicketActions::Util

      def create_tickets(threads)
        threads.each do |thread|
          thread = HashWithIndifferentAccess.new(thread)
          fb_msg          = latest_message(thread[:id])
          previous_ticket = fb_msg.try(:postable)
          last_reply = if previous_ticket.present? && previous_ticket.notes.exists?
                         previous_ticket.notes.latest_facebook_message.try(:first)
                       end
          last_reply = last_reply.presence || previous_ticket
          if last_reply && (Time.zone.now < (last_reply.created_at + @fan_page.dm_thread_time.seconds))
            add_as_note(thread, previous_ticket)
          else
            add_as_ticket(thread)
          end
        end
      end

      private

        def add_as_note(thread, ticket)
          thread_id         = thread[:id]
          messages          = thread[:messages]
          filtered_messages = filter_messages_from_data_set(messages)
          filtered_messages.reverse_each do |message|
            user                       = facebook_user(message[:from])
            @note                      = ticket.notes.build(
              private:            true,
              incoming:           true,
              source:             Helpdesk::Source.note_source_keys_by_token['facebook'],
              account_id:         @fan_page.account_id,
              user:               user,
              created_at:         Time.zone.parse(message[:created_time]),
              fb_post_attributes: {
                post_id:          message[:id],
                facebook_page_id: @fan_page.id,
                account_id:       @account.id,
                msg_type:         'dm',
                thread_id:        thread_id,
                thread_key:       thread[:id]
              }
            )
            begin
            body_html                  = html_content_from_message(message, @note)
            @note.note_body_attributes = {
              body_html: body_html
            }
            save_facebook_note(user)
            rescue OpenURI::HTTPError, URI::InvalidURIError, RuntimeError, StandardError => e
              Rails.logger.debug "Error in add_as_note Err:#{e.message}, Message: #{message.inspect}, Shares:#{message[:shares]}"
              return nil
            end
          end
        end

        def save_facebook_note(user)
          user.make_current
          Rails.logger.debug "error while saving the note #{@note.errors.to_json}" unless @note.save_note
        ensure
          User.reset_current_user
        end

        def add_as_ticket(thread)
          messages = thread[:messages]
          messages = filter_messages_from_data_set(messages)
          message  = messages.last
          group_id = @fan_page.dm_stream.ticket_rules.first.group_id
          return if !message || @account.facebook_posts.exists?(post_id: message[:id])

          first_message_from_customer = message
          profile   = if is_a_page?(message[:from], @fan_page.page_id)
                        first_message_from_customer, _notes_to_be_skipped = first_customer_message(messages)
                        return unless first_message_from_customer

                        first_message_from_customer[:from]
                      else
                        message[:from]
                      end
          requester = facebook_user(profile)

          @ticket = @account.tickets.build(
            subject:            truncate_subject(tokenize(first_message_from_customer[:message]), 100),
            requester:          requester,
            product_id:         @fan_page.product_id,
            group_id:           group_id,
            source:             Helpdesk::Source::FACEBOOK,
            created_at:         Time.zone.parse(first_message_from_customer[:created_time]),
            fb_post_attributes: {
              post_id:          first_message_from_customer[:id],
              facebook_page_id: @fan_page.id,
              account_id:       @account.id,
              msg_type:         'dm',
              thread_id:        thread[:id],
              thread_key:       thread[:id]
            }
          )
          begin
          description_html               = html_content_from_message(first_message_from_customer, @ticket)
          
          @ticket.ticket_body_attributes = {
            description_html: description_html
          }

          if @ticket.save_ticket
            add_as_note(thread, @ticket) if messages.size > 1
          else
            Rails.logger.debug "error while saving the ticket:: #{@ticket.errors.to_json}"
          end
          rescue OpenURI::HTTPError, URI::InvalidURIError, RuntimeError, StandardError => e
            Rails.logger.debug "Error in add_as_note Err:#{e.message}, Message: #{message.inspect}, Shares:#{message[:shares]}"
            return nil
          end
        end
    end
  end
end
