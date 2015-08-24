#!/bin/env ruby
# encoding: utf-8

class Helpdesk::Email::HandleTicket

  include ParserUtil
  include EmailCommands
  include EmailHelper
  include Helpdesk::Utils::Attachment
  include Helpdesk::Email::ParseEmailData
  include Helpdesk::Email::NoteMethods
  include Helpdesk::Email::TicketMethods
  include ActionView::Helpers
  include Helpdesk::DetectDuplicateEmail

  attr_accessor :note, :email, :user, :account, :ticket, :original_sender

  BODY_ATTR = ["body", "body_html", "full_text", "full_text_html", "description", "description_html"]

  def initialize email, user, account, ticket=nil
    self.email = email 
    self.original_sender = email[:from][:email]
    #the param hash is a shallow duplicate. Reference to hashes and arrays inside are to the common_email_data in process.rb. 
    #Any changes here can reflect there.
    self.user = user
    self.account = account
    self.ticket = ticket
    remove_unwanted_email_ids
  end

  def remove_unwanted_email_ids
    #Using a delete_if could have been better. But that would change the actual cc array in process.rb. Deep duplication required
    self.email[:cc] = email[:cc].reject{ |cc_hash| kbase_email?(cc_hash) }
    self.email[:to_emails] = email[:to_emails].reject{ |cc_hash| kbase_email?(cc_hash) or requester_email?(cc_hash) }
  end

  def kbase_email?(email)
    email == account.kbase_email
  end

  def requester_email?(email)
    ticket and email == ticket.requester.email
  end

  #-------------------------------------TICKET PART----------------------------------------------

	def create_ticket(start_time)
    create_ticket_object
    check_valid_ticket
    handle_ticket_email_commands if current_agent?
    # Creating attachments without attachable info
    # Hitting S3 outside create-ticket transaction
    # attachable info will be updated on ticket save
    self.class.trace_execution_scoped(['Custom/Mailgun/ticket_attachments']) do
      ticket.attachments, ticket.inline_attachments = build_attachments(ticket)
    end
    self.class.trace_execution_scoped(['Custom/Mailgun/tickets']) do
      return if large_email(start_time) && duplicate_email?(email[:from][:email],
                                                            email[:to][:email],
                                                            email[:subject],
                                                            email[:message_id][1..-2])
      finalize_ticket_save
      mark_email(process_email_key(email[:message_id][1..-2]), email[:from][:email],
                                    email[:to][:email],
                                    email[:subject],
                                    email[:message_id][1..-2]) if large_email(start_time)
    end
	end

  #-------------------------------------NOTE PART-------------------------------------------------

	def create_note(start_time)
    build_note_object
    begin
      update_ticket_cc
      handle_note_email_commands if (user.agent? && !user.deleted?)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
    # Creating attachments without attachable info
    # Hitting S3 outside create-note transaction
    # attachable info will be updated on note save
    self.class.trace_execution_scoped(['Custom/Mailgun/note_attachments']) do
      note.attachments, note.inline_attachments = build_attachments(note)
    end
    
    self.class.trace_execution_scoped(['Custom/Mailgun/notes']) do
      note.notable = ticket
      return if large_email(start_time) && duplicate_email?(email[:from][:email],
                                                            email[:to][:email],
                                                            email[:subject],
                                                            email[:message_id][1..-2])
      note.save_note
      cleanup_attachments note
      mark_email(process_email_key(email[:message_id][1..-2]), email[:from][:email],
                                    email[:to][:email],
                                    email[:subject],
                                    email[:message_id][1..-2]) if large_email(start_time)
    end
	end

#-------------------------------------ATTACHMENTS PART--------------------------------------------

	def build_attachments item
    attachments = []
    inline_attachments = []
    content_id_hash = {}
    email[:attached_items].count.times do |i|
      begin
        att = Helpdesk::Attachment.create_for_3rd_party(account, item, 
                                                        email[:attached_items]["attachment-#{i+1}"], 
                                                        i, cid(i), true)
        if att.is_a? Helpdesk::Attachment
          if cid(i)
            content_id_hash[att.content_file_name+"#{i}"] = cid(i)
            inline_attachments.push att
          else
            attachments.push att
          end
        end
      rescue HelpdeskExceptions::AttachmentLimitException => ex
        Rails.logger.error("ERROR ::: #{ex.message}")
        add_notification_text item
        break
      rescue Exception => e
        Rails.logger.error("Error while adding item attachments for ::: #{e.message}")
        break
      end
    end
    item.header_info = {:content_ids => content_id_hash} unless content_id_hash.blank?
    return attachments, inline_attachments
	end

  # Content-id for inline attachments
  def cid(i)
    email[:content_ids]["attachment-#{i+1}"]
  end

  def add_notification_text item
    message = attachment_exceeded_message(HelpdeskAttachable::MAILGUN_MAX_ATTACHMENT_SIZE)
    notification_text = "\n" << message
    notification_text_html = Helpdesk::HTMLSanitizer.clean(content_tag(:div, message, :class => "attach-error"))
    if item.is_a?(Helpdesk::Ticket)
      item.description << notification_text
      item.description_html << notification_text_html
    elsif item.is_a?(Helpdesk::Note)
      item.body << notification_text
      item.body_html << notification_text_html
    end
  end

  def attachment_params attachment_name
    {
      :content => email[:attached_items][attachment_name],
      :account_id => ticket.account_id,
      :description => (email[:content_ids][attachment_name] ? "content_id" : "")
    }
  end

  #--------------------------------------EMAIL COMMANDS PART------------------------------------------

  def handle_ticket_email_commands
    begin
      process_email_commands(ticket, user, email[:email_config], email) if user.privilege?(:edit_ticket_properties)
      remove_email_commands(ticket.ticket_body)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  def handle_note_email_commands
    process_email_commands(ticket, user, ticket.email_config, email, note) if user.privilege?(:edit_ticket_properties)
    remove_email_commands(note.note_body)
  end

  def remove_email_commands source
    email_cmds_regex = get_email_cmd_regex(account)
    BODY_ATTR.each do |f|
      v = source[f.to_sym]
      source[f.to_sym] = v.gsub(email_cmds_regex, "") if(v.present? && email_cmds_regex)
    end
  end
end