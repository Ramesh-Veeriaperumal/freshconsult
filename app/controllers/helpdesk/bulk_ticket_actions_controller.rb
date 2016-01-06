
class Helpdesk::BulkTicketActionsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include ParserUtil
  include HelpdeskControllerMethods
  include Helpdesk::TagMethods

  before_filter :filter_params_ids, :validate_params, :scoper_bulk_actions, :only => :update_multiple
  before_filter :load_items, :only => :update_multiple

  def update_multiple
    failed_tickets = []

    @items.each do |ticket|
      params[nscname].each do |key, value|
        ticket.send("#{key}=", value) if !value.blank? and ticket.respond_to?("#{key}=")
      end
      update_tags(params[:helpdesk][:tags], false, ticket) unless params[:helpdesk].blank? or params[:helpdesk][:tags].nil?
      ticket.save_ticket
    end
    flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/bulk_actions_notice', 
                                      :locals => { :failed_tickets => failed_tickets, :get_updated_ticket_count => get_updated_ticket_count })
    queue_replies
    redirect_to helpdesk_tickets_path
  end

  protected

    def queue_replies
      if privilege?(:reply_ticket) and reply_content.present?
        return unless check_attachments
        begin
          Timeout::timeout(SpamConstants::SPAM_TIMEOUT) do
            key = "#{current_user.account_id}-#{current_user.id}"
            value = Time.now.to_i.to_s
            $spam_watcher.setex(key,24.hours,value)
            params["spam_key"] = "#{key}:#{value}"
          end
        rescue Exception => e
          NewRelic::Agent.notice_error(e,{:description => "error occured while adding key in redis"})
        end
        #Resque.enqueue(Workers::BulkReplyTickets, params_for_queue)
        args = params_for_queue
        Tickets::BulkTicketReply.perform_async(args)
      end
    end

    def reply_content
      params[:helpdesk_note][:note_body_attributes] ? 
        params[:helpdesk_note][:note_body_attributes][:body_html] : nil
    end

    def check_attachments
      return true if params[:helpdesk_note][:attachments].blank?
      if total_attachment_size > 15.megabyte
        flash[:notice] = t('helpdesk.tickets.note.attachment_size.exceed')
        return false
      end
      save_attachments

    end

    def load_by_param(id)
      current_account.tickets.find_by_param(id,current_account)
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
      params.slice('ids', 'helpdesk_note', 'twitter_handle', 'cloud_file_attachments', 'shared_attachments', 'spam_key', 'email_config')
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

   private

    def params_for_bulk_action
      params.slice('ids')
    end

    def validate_params
      #Removing invalid ticket types
      ticket_types = Account.current.ticket_types_from_cache.collect(&:value)
      unless ticket_types.include?(params[:helpdesk_ticket][:ticket_type])
        params[:helpdesk_ticket].delete(:ticket_type)
      end
    end

    def scoper_bulk_actions
      if params[:ids] and params[:ids].length > BACKGROUND_THRESHOLD
        update_multiple_background
      end
    end

    def update_multiple_background
      args = { :action => action_name, :helpdesk_ticket => params[:helpdesk_ticket] }
      args.merge!(params_for_bulk_action)
      args[:tags] = params[:helpdesk][:tags] unless params[:helpdesk].blank? or params[:helpdesk][:tags].nil?
      Tickets::BulkTicketActions.perform_async(args) if args[:helpdesk_ticket] or args[:tags]
      queue_replies
      respond_to do |format|
        format.html {
          flash[:notice] = t('helpdesk.flash.tickets_background')
          redirect_to helpdesk_tickets_path
        }
      end
    end
end
