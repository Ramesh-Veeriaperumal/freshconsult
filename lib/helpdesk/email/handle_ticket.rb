#!/bin/env ruby
# encoding: utf-8

class Helpdesk::Email::HandleTicket

  include ParserUtil
  include EmailCommands
  include Helpdesk::Utils::Attachment
  include Helpdesk::Email::ParseEmailData
  include Helpdesk::Email::NoteMethods
  include Helpdesk::Email::TicketMethods
  include ActionView::Helpers

  attr_accessor :note, :email, :user, :account, :ticket

  BODY_ATTR = ["body", "body_html", "full_text", "full_text_html", "description", "description_html"]

  def initialize email, user, account, ticket=nil
    self.email = email 
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

	def create_ticket
    create_ticket_object
    check_valid_ticket
    handle_ticket_email_commands if current_agent?
    build_attachments(ticket)
    finalize_ticket_save
	end

  #-------------------------------------NOTE PART-------------------------------------------------

	def create_note
    build_note_object
    begin
      update_ticket_cc
      handle_note_email_commands if (user.agent? && !user.deleted?)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
    build_attachments(note)
    # ticket.save
    note.notable = ticket
    note.save_note
	end

#-------------------------------------ATTACHMENTS PART--------------------------------------------

	def build_attachments item
    content_id_hash = {}
    email[:attached_items].each_with_index do |(key,attached),i|
      file = create_attachment(item, "attachment-#{i+1}")
      content_id_hash[file.content_file_name+"#{i}"] = cid(i) if file.is_a? Helpdesk::Attachment and cid(i)
    end
    item.header_info = {:content_ids => content_id_hash} unless content_id_hash.blank?
	end

  # Content-id for inline attachments
  def cid(i)
    email[:content_ids]["attachment-#{i+1}"]
  end

  def create_attachment item, attachment_name
    begin
      create_attachment_from_params(item, attachment_params(attachment_name), nil,
                                    attachment_name)
    rescue HelpdeskExceptions::AttachmentLimitException => ex
      Rails.logger.error("ERROR ::: #{ex.message}")
      add_notification_text item
    rescue Exception => e
      Rails.logger.error("Error while adding item attachments for ::: #{e.message}")
    end
  end

  def add_notification_text item
    message = I18n.t('attachment_failed_message').html_safe
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