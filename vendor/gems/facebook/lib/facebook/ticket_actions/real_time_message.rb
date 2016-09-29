module Facebook
	module TicketActions
		module RealTimeMessage

			include Social::Util
			include Facebook::Util
			include Facebook::TicketActions::Util

			def create_tickets(message,thread_id)
	    	  fb_msg = @account.facebook_posts.latest_thread(thread_id, 1).first
	    	  previous_ticket = fb_msg.try(:postable)
	    	  last_reply = unless previous_ticket.blank?
	    	    if (!previous_ticket.notes.blank? && !previous_ticket.notes.latest_facebook_message.blank?)
	    	      previous_ticket.notes.latest_facebook_message.first
	    	    else
	    	      previous_ticket
	    	    end
	    	  end
	    	  if last_reply && (Time.zone.now < (last_reply.created_at + @fan_page.dm_thread_time.seconds))
	    	    add_as_note(thread_id, message, previous_ticket)
	    	  else
	    	    add_as_ticket(thread_id, message)
	    	  end
			end

			private

			def add_as_note(thread_id, message, ticket)
			  message.symbolize_keys!
			  return if @account.facebook_posts.exists?(:post_id => message[:id])
			  user = facebook_user(message[:from])
			  message[:message] = message[:message].to_s.tokenize_emoji
			  
			  @note = ticket.notes.build(
			    :note_body_attributes => {
			      :body_html => html_content_from_message(message)
			    },
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
			      :thread_id        =>  thread_id
			    }
			  )

			  begin
			    user.make_current
			    unless @note.save_note
			      Rails.logger.debug "error while saving the note #{@note.errors.to_json}"
			    end
			  ensure
			    User.reset_current_user
			  end
			end

			def add_as_ticket(thread_id,message)
			  message.symbolize_keys!
			  group_id = Account.current.features?(:social_revamp) ? @fan_page.dm_stream.ticket_rules.first.group_id : @fan_page.group_id
			  
			  return if !message or @account.facebook_posts.exists?(:post_id => message[:id])

			  requester         = facebook_user(message[:from])
			  message[:message] = message[:message].to_s.tokenize_emoji

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
			      :thread_id          =>  thread_id
			    },
			    :ticket_body_attributes => {
			      :description_html => html_content_from_message(message)
			    }
			  )

			  if @ticket.save_ticket
			  	Rails.logger.debug "ticket successfully saved"
			  else
			    Rails.logger.debug "error while saving the ticket:: #{@ticket.errors.to_json}"
			  end
			end
		end
	end
end