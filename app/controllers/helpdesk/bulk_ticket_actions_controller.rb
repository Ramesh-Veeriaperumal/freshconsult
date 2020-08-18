
class Helpdesk::BulkTicketActionsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include ParserUtil
  include HelpdeskControllerMethods
  include Helpdesk::TagMethods
  include Helpdesk::Ticketfields::TicketStatus
  include Helpdesk::BulkActionMethods
  include TicketValidationMethods

  before_filter :update_multiple_methods, :only => :update_multiple

  def update_multiple

  end

  protected

    def get_updated_ticket_count   
      pluralize(@items.length, t('ticket_was'), t('tickets_were'))    
    end

    def update_multiple_methods
      filter_params_ids
      validate_params
      validate_ticket_close
      update_multiple_background
      load_items if items_empty? 
    end
    def validate_ticket_close
      @failed_tickets = []
      if params[:helpdesk_ticket] and params[:helpdesk_ticket][:status].present? and close_action?(params[:helpdesk_ticket][:status].to_i)
        values_hash = params[:helpdesk_ticket][:custom_field] ? params[:helpdesk_ticket].merge(params[:helpdesk_ticket][:custom_field]) : params[:helpdesk_ticket]
        load_items
        @items.each do |ticket|
          ticket.attributes = values_hash
          unless valid_ticket?(ticket)
            remove_from_params ticket
          end
        end
      end
    end

    def queue_replies
      if privilege?(:reply_ticket) and reply_content.present?
        return unless check_attachments
        begin
          Timeout::timeout(SpamConstants::SPAM_TIMEOUT) do
            key = "#{current_user.account_id}-#{current_user.id}"
            value = Time.now.to_i.to_s
            $spam_watcher.perform_redis_op("setex", key, 24.hours, value)
            params["spam_key"] = "#{key}:#{value}"
          end
        rescue Exception => e
          NewRelic::Agent.notice_error(e,{:description => "error occured while adding key in redis"})
        end
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
      if total_attachment_size > current_account.attachment_limit.megabyte
        flash[:notice] = t('helpdesk.tickets.note.attachment_size.exceeded', :attachment_limit => current_account.attachment_limit)
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

    def cname
      @cname ||= 'tickets'
    end

    def nscname
      'helpdesk_ticket'
    end

   private

    def display_flash failed_tickets
      @failed_tickets ||= failed_tickets
      if @failed_tickets.length == 0
        flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/bulk_actions_notice', 
                                        :locals => { :failed_tickets => @failed_tickets, :get_updated_ticket_count => get_updated_ticket_count })
      else
        flash[:failed_tickets] = @failed_tickets
        flash[:action] = "bulk_scenario_close"
        flash[:notice] = render_to_string(
              :inline => t("helpdesk.flash.tickets_close_fail_on_bulk_action", 
              :tickets => get_updated_ticket_count,
              :failed_tickets => "<%= link_to( t('helpdesk.flash.tickets_failed', :failed_count => @failed_tickets.count), '',  id: 'failed-tickets' )%>" )).html_safe
      end
    end

    def params_for_bulk_action
      params.slice('ids')
    end

    def validate_params
      #Removing invisible ticket fields
      delete_invisible_fields

      #Removing invalid ticket types
      ticket_types = Account.current.ticket_types_from_cache.collect(&:value)
      if @field_params and !ticket_types.include?(@field_params[:ticket_type])
        @field_params.delete(:ticket_type)
      end
    end

    def update_multiple_background
      args = { :action => action_name, :helpdesk_ticket => @field_params }
      args.merge!(params_for_bulk_action)
      args[:tags] = params[:helpdesk][:tags] unless params[:helpdesk].blank? or params[:helpdesk][:tags].nil?
      ::Tickets::BulkTicketActions.perform_async(args) if args[:helpdesk_ticket].present? or args[:tags].present?
      queue_replies
      respond_to do |format|
        format.html {
          if @failed_tickets.length == 0
            flash[:notice] = t('helpdesk.flash.tickets_background')
          else
            flash[:failed_tickets] = @failed_tickets
            flash[:action] = "bulk_scenario_close"            
            flash[:notice] = render_to_string(
            :inline => t("helpdesk.flash.tickets_close_fail_on_bulk_action", 
            :tickets => get_updated_ticket_count,
            :failed_tickets => "<%= link_to( t('helpdesk.flash.tickets_failed', :failed_count => @failed_tickets.count), '',  id: 'failed-tickets') %>" )).html_safe

          end
          redirect_to helpdesk_tickets_path
        }
      end
    end

    def delete_invisible_fields
      @field_params = params[:helpdesk_ticket] ? params[:helpdesk_ticket].dup : params[:helpdesk_ticket]
      if @field_params.present?
        @field_params.keys.each do |key|
          if key == "custom_field"
            @field_params[key].delete_if {|key, value| !visible_custom_fields.include?(key)}
          elsif key == "skill_id"
            @field_params.delete(key) unless has_edit_ticket_skill_privilege?
          else
            @field_params.delete(key) unless visible_default_fields.include?(key)
          end
        end
      end
    end

    def visible_default_fields
      @default ||= TicketConstants::SHARED_DEFAULT_FIELDS_ORDER.values
    end

    def visible_custom_fields
      @custom ||= current_account.ticket_fields_with_nested_fields.nested_and_dropdown_fields.pluck(:name)
    end
end
