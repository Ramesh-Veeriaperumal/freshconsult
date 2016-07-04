# encoding: utf-8
module Helpdesk::MergeTicketActions

	include Helpdesk::Ticketfields::TicketStatus
	include Helpdesk::ToggleEmailNotification
	include ParserUtil
  include Redis::RedisKeys
  include Redis::OthersRedis

	def handle_merge 
    @header = @target_ticket.header_info || {}
    @source_tickets.each do |source_ticket|
			move_source_time_sheets_to_target(source_ticket)
			move_source_description_to_target(source_ticket)
			#setting an attr accessor variable for activities
			source_ticket.activity_type = {:type => "ticket_merge_source", 
				:source_ticket_id => [source_ticket.display_id], 
				:target_ticket_id => [@target_ticket.display_id]}
			close_source_ticket(source_ticket)
			update_header_info(source_ticket.header_info) if source_ticket.header_info
		end
    move_source_notes_to_target
		add_header_to_target if !@header.blank?
		move_source_requesters_to_target if params[:add_recipients]
		add_note_to_target_ticket
	end

	private

		def move_source_notes_to_target
			MergeTickets.perform_async({ :source_ticket_ids => @source_tickets.map(&:display_id),
                                              :target_ticket_id => @target_ticket.id, 
                                              :source_note_private => params[:source][:is_private],
                                              :source_note => params[:source][:note] })
	  end

		def move_source_description_to_target source_ticket
			desc_pvt_note = params[:target][:is_private]
			source_description_note = @target_ticket.notes.build(
				:note_body_attributes => {:body_html => build_source_description_body_html(source_ticket)},
				:private => desc_pvt_note || false,
				:source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
				:account_id => current_account.id,
				:user_id => current_user && current_user.id
			)
			source_description_note.save_note
			MergeTicketsAttachments.perform_async({ :source_ticket_id => source_ticket.id,
												:target_ticket_id => @target_ticket.id,	
                                              	:source_description_note_id => source_description_note.id })
		end

		def build_source_description_body_html source_ticket
		  %{#{I18n.t('helpdesk.merge.bulk_merge.target_merge_description1', :ticket_id => source_ticket.display_id, 
																							      	:full_domain => source_ticket.portal.host)}<br/><br/>
		    <b>#{I18n.t('Subject')}:</b> #{source_ticket.subject}<br/><br/>
		    <b>#{I18n.t('description')}:</b><br/>#{source_ticket.description_html}}
		end

		def move_source_requesters_to_target
			reply_cc_email_array = get_emails_list
			cc_email_array = get_email_array(reply_cc_email_array)
			return unless cc_email_array.any?
			if @target_ticket.cc_email.blank?
				@target_ticket.cc_email = {
					:cc_emails => cc_email_array,
					:fwd_emails => [],
					:reply_cc => reply_cc_email_array,
					:tkt_cc => []
				}
			else
				@target_ticket.cc_email[:cc_emails] = (get_cc_email_from_hash(@target_ticket) + cc_email_array).uniq
				@target_ticket.cc_email[:reply_cc] =  (@target_reply_cc + reply_cc_email_array).first(TicketConstants::MAX_EMAIL_COUNT - 1)
			end
			@target_ticket.save
		end

		def move_source_time_sheets_to_target source_ticket
		  source_ticket.time_sheets.each do |time_sheet|
		    time_sheet.update_attribute(:workable_id, @target_ticket.id)
		  end
		end

		def close_source_ticket source_ticket
		  disable_notification
		  source_ticket.parent_ticket = @target_ticket.id
		  source_ticket.update_attribute(:status , CLOSED)
		  enable_notification
		end

		def update_header_info source_header
			(source_header[:message_ids] || []).each do |source|
				@header[:message_ids] = [] unless @header.key?(:message_ids)
				unless @header[:message_ids].include? source
					@header[:message_ids] << source
					source_key = EMAIL_TICKET_ID % { :account_id => current_account.id, :message_id => source }
					set_others_redis_key(source_key, "#{@target_ticket.display_id}:#{source}", 86400*7)
				end
			end
		end

		def add_header_to_target
			@target_ticket.header_info = @header
			@target_ticket.schema_less_ticket.save
		end

		def add_note_to_target_ticket
		  target_pvt_note = @target_ticket.requester_has_email? ? params[:target][:is_private] : true
			@target_note = @target_ticket.notes.build(
				:note_body_attributes => {:body_html => params[:target][:note]},
				:private => target_pvt_note  || false,
				:source => target_pvt_note ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : 
																Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
				:account_id => current_account.id,
				:user_id => current_user && current_user.id,
				:from_email => @target_ticket.reply_email,
				:to_emails => target_pvt_note ? [] : @target_ticket.requester.email.lines.to_a,
				:cc_emails => target_pvt_note ? [] : @target_ticket.cc_email_hash && @target_ticket.cc_email_hash[:cc_emails]
			)
			@target_note.save_note 
			@target_note
		end

		def get_emails_list
			@target_reply_cc = get_reply_cc_email_from_hash(@target_ticket)
			emails_list = []
			@source_tickets.each do |source|
				emails_list += get_reply_cc_email_from_hash(source)
				emails_list << add_source_requester(source) if check_source_requester(source)
			end
			emails_list = remove_duplicates(emails_list)
			emails_list.delete_if { |e| reject_email?(parse_email_text(e)[:email]) }
		end

		def remove_duplicates emails_list
			emails_hash = Hash[ emails_list.map { |e| [parse_email_text(e)[:email], e] } ]
			emails_hash.values
		end

		def reject_email? email
			target_reply_cc_emails = get_email_array(@target_reply_cc)
			email == @target_ticket.requester.email || target_reply_cc_emails.include?(email)
		end

		def add_source_requester ticket
			%{#{ticket.requester.name} <#{ticket.requester.email}>}
		end

    def get_cc_email_from_hash ticket
      ticket.cc_email ? (ticket.cc_email[:cc_emails] ? get_email_array(ticket.cc_email[:cc_emails]) : []) : []
    end

    def get_reply_cc_email_from_hash ticket
      ticket.cc_email ? (ticket.cc_email[:reply_cc] ? ticket.cc_email[:reply_cc] : []) : []
    end

		def check_source_requester source_ticket
			source_ticket.requester_has_email? && !source_ticket.requester.eql?(@target_ticket.requester)
		end
end	
