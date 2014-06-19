require 'fastercsv'

class Helpdesk::BulkTicketActionsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include ParserUtil
  include HelpdeskControllerMethods
  include Helpdesk::TagMethods

  before_filter :filter_params_ids, :only => :update_multiple
  before_filter :load_multiple_items, :only => :update_multiple

  def update_multiple             
    failed_tickets = []
    
    @items.each do |ticket|
      params[nscname].each do |key, value|
        ticket.send("#{key}=", value) if !value.blank? and ticket.respond_to?("#{key}=")
      end
      ticket.save_ticket
      update_tags(params[:helpdesk_tags][:tags], false, ticket) unless params[:helpdesk_tags].blank?
    end
    flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/bulk_actions_notice', 
                                      :locals => { :failed_tickets => failed_tickets, :get_updated_ticket_count => get_updated_ticket_count })
    queue_replies
    redirect_to helpdesk_tickets_path
  end

  protected

    def queue_replies
      reply_content =  params[:helpdesk_note][:note_body_attributes][:body_html]
      if privilege?(:reply_ticket) and reply_content.present?
        return unless check_attachments
        Resque.enqueue(Workers::BulkReplyTickets, params_for_queue)
      end
    end

    def check_attachments
      return true if params[:helpdesk_note][:attachments].blank?
      if total_attachment_size > 15.megabyte
        flash[:notice] = t('helpdesk.tickets.note.attachment_size.exceed')
        return false
      end
      save_attachments

    end

    def total_attachment_size
      (params[:helpdesk_note][:attachments] || []).collect{ |a| a['resource'].size }.sum
    end

    def save_attachments
      saved_attachments = []
      (params[:helpdesk_note][:attachments] || []).each do |a|
        attached = current_account.attachments.build({
                      :content => a[:resource], 
                      :attachable_type => "Account", :attachable_id => current_account.id
                    })
        if attached.save
          saved_attachments << attached.id 
        else
          Rails.logger.error "Could not save the file :: #{a[:resource].inspect}"
        end
      end
      params[:helpdesk_note][:attachments] = saved_attachments
    end

    def params_for_queue
      params.slice('ids', 'helpdesk_note', 'twitter_handle', 'dropbox_url', 'shared_attachments')
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
