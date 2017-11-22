module Facebook
  module TicketActions
    module DirectMessage
      
      include Social::Util
      include Facebook::Util
      include Facebook::TicketActions::Util
          
      def create_tickets(threads)
        threads.each do |thread|
          thread.symbolize_keys!
          msg_ids = thread[:messages]["data"].map { |msg| msg["id"]}
          fb_msg = latest_message(thread[:thread_key], thread[:id], msg_ids)
          previous_ticket = fb_msg.try(:postable)

          last_reply = unless previous_ticket.blank?
            if (!previous_ticket.notes.blank? && !previous_ticket.notes.latest_facebook_message.blank?)
              previous_ticket.notes.latest_facebook_message.first
            else
              previous_ticket
            end
          end
          if last_reply && (Time.zone.now < (last_reply.created_at + @fan_page.dm_thread_time.seconds))
            add_as_note(thread, previous_ticket)
          else
            add_as_ticket(thread)
          end

          if fb_msg.present? && fb_msg.thread_key.nil?
            @account.facebook_posts.where({:thread_id => thread[:id], :facebook_page_id => @fan_page.id, :thread_key => nil}).find_each do |fb_post| 
              fb_post.update_attributes({:thread_key => thread[:thread_key]})
            end
          end
        end
      end

      private

      def add_as_note(thread, ticket)
        thread_id = thread[:id]
        messages  = thread[:messages].symbolize_keys!
        messages[:data].reverse.each do |message|

          message.symbolize_keys!
          next if note_skip_conditions(message, ticket)
          user = facebook_user(message[:from])
          message[:message] = tokenize(message[:message])

          @note = ticket.notes.build(
            :private    =>  true ,
            :incoming   =>  true,
            :source     =>  Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
            :account_id =>  @fan_page.account_id,
            :user       =>  user,
            :created_at =>  Time.zone.parse(message[:created_time]),
            :fb_post_attributes => {
              :post_id          =>  message[:id],
              :facebook_page_id =>  @fan_page.id,
              :account_id       =>  @account.id,
              :msg_type         =>  'dm',
              :thread_id        =>  thread_id,
              :thread_key       =>  thread[:thread_key]
            }
          )
          body_html = html_content_from_message(message, @note)
          @note.note_body_attributes = {
            :body_html => body_html
          }

          begin
            user.make_current
            unless @note.save_note
              Rails.logger.debug "error while saving the note #{@note.errors.to_json}"
            end
          ensure
            User.reset_current_user
          end
        end
      end

      def add_as_ticket(thread)
        messages = thread[:messages].symbolize_keys!
        messages = filter_messages_from_data_set(messages)
        message  = messages.last
        group_id = Account.current.features?(:social_revamp) ? @fan_page.dm_stream.ticket_rules.first.group_id : @fan_page.group_id
        
        return if !message or @account.facebook_posts.exists?(:post_id => message[:id])
        first_message_from_customer = message
        message.symbolize_keys!
        profile = if is_a_page?(message[:from], @fan_page.page_id)
                    first_message_from_customer, notes_to_be_skipped = find_user_with_skipped_messages(messages)
                    return unless first_message_from_customer
                    first_message_from_customer[:from]
                  else
                    message[:from]
                  end
        requester = facebook_user(profile)
        first_message_from_customer[:message] = tokenize(first_message_from_customer[:message])

        @ticket = @account.tickets.build(
          :subject      =>  truncate_subject(first_message_from_customer[:message], 100),
          :requester    =>  requester,
          :product_id   =>  @fan_page.product_id,
          :group_id     =>  group_id,
          :source       =>  Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
          :created_at   =>  Time.zone.parse(first_message_from_customer[:created_time]),
          :fb_post_attributes => {
            :post_id            =>  first_message_from_customer[:id],
            :facebook_page_id   =>  @fan_page.id,
            :account_id         =>  @account.id,
            :msg_type           =>  'dm',
            :thread_id          =>  thread[:id],
            :thread_key         =>  thread[:thread_key]
          }
        )
        description_html = html_content_from_message(first_message_from_customer, @ticket)
        @ticket.ticket_body_attributes = {
          :description_html => description_html
        }

        if @ticket.save_ticket
          add_as_note(thread, @ticket) if messages.size > 1
        else
          Rails.logger.debug "error while saving the ticket:: #{@ticket.errors.to_json}"
        end
      end

      def note_skip_conditions(message, ticket)
        note_created_at = message[:created_time]
        ((@fan_page.created_at > Time.zone.parse(note_created_at)) || (ticket.created_at > Time.zone.parse(note_created_at)) || @account.facebook_posts.exists?(:post_id => message[:id]))
      end
    end
  end
end
