require 'fastercsv'

class Helpdesk::BulkTicketActionsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include ParserUtil
  include HelpdeskControllerMethods  
  include Helpdesk::Social::Facebook
  include Helpdesk::Social::Twitter

  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :load_multiple_items, :validate_attachment_size, :only => :update_multiple

  def update_multiple

    raise I18n.t('set_priority_error') if
              !params[nscname][:priority].blank? && !privilege?(:ticket_priority)
    raise I18n.t('close_ticket_error') if
              (params[nscname][:status] == Helpdesk::Ticketfields::TicketStatus::CLOSED) &&
              !privilege?(:close_ticket)
              
    # params[nscname][:custom_field].delete_if {|key,value| value.blank? } unless 
    #           params[nscname][:custom_field].nil?
    reply_content = params[:helpdesk_note][:body_html]
    failed_tickets = []
    @items.each do |ticket|
      params[nscname].each do |key, value|
        ticket.send("#{key}=", value) if !value.blank? and ticket.respond_to?("#{key}=")
      end
      ticket.save
      begin
        reply_multiple reply_content, ticket
      rescue Exception => e
        failed_tickets.push(ticket)
        NewRelic::Agent.notice_error(e)
        Rails.logger.error("Error while sending reply")
      end
    end
    flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/bulk_actions_notice', 
                                      :locals => { :failed_tickets => failed_tickets, :get_updated_ticket_count => get_updated_ticket_count })
    redirect_to helpdesk_tickets_path
  end

  protected

    def reply_multiple reply_content, ticket
      return if reply_content.blank? 
      build_note_params ticket, reply_content
      note = ticket.notes.build(params[:helpdesk_note])
      build_attachments note, :helpdesk_note
      send("#{note.source_name}_reply", ticket, note) if note.save
    end

    def build_note_params ticket, reply_content
      source = Helpdesk::Note::TICKET_NOTE_SOURCE_MAPPING[ticket.source]
      params[:helpdesk_note].merge!( :source => source, 
        :body_html => Liquid::Template.parse(reply_content).render(
        'ticket' => ticket, 'helpdesk_name' => ticket.portal_name) )
    end  

    def email_reply ticket, note
      Helpdesk::TicketNotifier.send_later(:deliver_reply, ticket, note);    
    end

    def facebook_reply ticket, note
      ticket.is_fb_message? ? send_facebook_message (ticket, note) : send_facebook_comment (ticket, note)
    end
    
    def twitter_reply ticket, note
      params[:twitter_handle] = ticket.fetch_twitter_handle
      twt_type = ticket.tweet.tweet_type || :mention.to_s
      send("send_tweet_as_#{twt_type}", ticket, note)
    end

    def get_updated_ticket_count
      pluralize(@items.length, t('ticket_was'), t('tickets_were'))
    end  
    
    def cname
      @cname ||= 'tickets'
    end

    def nscname
      'helpdesk_ticket'
    end

end
