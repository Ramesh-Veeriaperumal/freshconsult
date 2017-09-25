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
          next if @account.facebook_posts.exists?(:post_id => message[:id])
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
        messages = new_data_set(messages)
        message  = messages.last
        group_id = Account.current.features?(:social_revamp) ? @fan_page.dm_stream.ticket_rules.first.group_id : @fan_page.group_id
        
        return if !message or @account.facebook_posts.exists?(:post_id => message[:id])

        message.symbolize_keys!
        requester         = facebook_user(message[:from])
        message[:message] = tokenize(message[:message])

        @ticket = @account.tickets.build(
          :subject      =>  truncate_subject(message[:message], 100),
          :requester    =>  requester,
          :product_id   =>  @fan_page.product_id,
          :group_id     =>  group_id,
          :source       =>  Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
          :created_at   =>  Time.zone.parse(message[:created_time]),
          :fb_post_attributes => {
            :post_id            =>  message[:id],
            :facebook_page_id   =>  @fan_page.id,
            :account_id         =>  @account.id,
            :msg_type           =>  'dm',
            :thread_id          =>  thread[:id],
            :thread_key         =>  thread[:thread_key]
          }
        )
        description_html = html_content_from_message(message, @ticket)
        @ticket.ticket_body_attributes = {
          :description_html => description_html
        }

        if @ticket.save_ticket
          add_as_note(thread, @ticket) if messages.size > 1
        else
          Rails.logger.debug "error while saving the ticket:: #{@ticket.errors.to_json}"
        end
      end
      
    end
  end
end
