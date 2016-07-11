# encoding: utf-8
class Helpdesk::AttachmentsController < ApplicationController

  include HelpdeskControllerMethods
  skip_before_filter :check_privilege
  before_filter :load_item, :only => [:text_content, :show]
  before_filter :check_download_permission, :only => [:show, :text_content]
  before_filter :check_destroy_permission, :only => [:destroy]
  before_filter :set_native_mobile, :only => [:show]
  before_filter :load_shared, :only => [:unlink_shared]
  def show
    style = params[:style] || "original"
    redir_url = AwsWrapper::S3Object.url_for(@attachment.content.path(style.to_sym),@attachment.content.bucket_name,
                                          :expires => 300.seconds, :secure => true, :response_content_type => @attachment.content_content_type)
    respond_to do |format|
      
      format.html do
        redirect_to redir_url
      end

      format.xml  do
        render :xml => @attachment.to_xml
      end
      format.nmobile do
        render :json => { "url" => redir_url}.to_json
      end
      format.all do
        redirect_to redir_url
      end
    end
  end

  def text_content
    style = params[:style] || "original"
    data = AwsWrapper::S3Object.read(@attachment.content.path(style.to_sym),@attachment.content.bucket_name)
    render :text => data
  end

  def scoper
    current_account.attachments
  end

  def load_item
    @attachment = @item = scoper.find(params[:id])

    @item || raise(ActiveRecord::RecordNotFound)
  end

  def unlink_shared
    if can_unlink?
      attachment_count
      @item.destroy
      flash[:notice] = t(:'flash.tickets.notes.remove_attachment.success')
    else
      flash[:notice] = t(:'flash.general.access_denied')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  protected

    def load_shared
      @item = Helpdesk::SharedAttachment.find_by_shared_attachable_id(params[:item_id], :conditions=>["attachment_id=?", params[:id]])
    end

    def can_unlink?
      if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? @item.shared_attachable_type
        privilege?(:manage_tickets)
      elsif ['Helpdesk::TicketTemplate'].include? @item.shared_attachable_type
        template_priv? @item.shared_attachable
      end
    end

    def attachment_count
      @obj                  = @item.shared_attachable
      @obj_name             = (@item.shared_attachable_type == "Helpdesk::Note") ? "note" : "ticket"
      @obj_attachment_count = @obj.all_attachments.size + @obj.cloud_files.size - 1
    end

    def check_download_permission
      access_denied unless can_download?
    end

    def can_download?
      # Is the attachment on a note?
      #if @attachment.attachable.respond_to?(:notable)
      if ['Helpdesk::Ticket', 'Helpdesk::Note', 'Mobihelp::TicketInfo', 'Helpdesk::ArchiveTicket','Helpdesk::ArchiveNote'].include? @attachment.attachable_type

        # If the user has high enough permissions, let them download it
        return true if(current_user && current_user.agent?)

        # Or if the note belogs to a ticket, and the user is the originator of the ticket
        ticket = @attachment.attachable.respond_to?(:notable) ? @attachment.attachable.notable : @attachment.attachable
        return ticket_access? ticket

      # Is the attachment on a solution  If so, it's always downloadable.

      elsif ['Solution::Article'].include? @attachment.attachable_type
        return @attachment.attachable.solution_folder_meta.visible?(current_user)
      elsif ['Post'].include? @attachment.attachable_type
        return @attachment.attachable && @attachment.attachable.forum.visible?(current_user)
      elsif ['Account', 'Portal'].include? @attachment.attachable_type
        return  true
      elsif ['Freshfone::Call'].include? @attachment.attachable_type
        return true if(current_user && current_user.agent?)
        return ticket_access? call_record_ticket
      elsif ['DataExport'].include? @attachment.attachable_type
        return privilege?(:manage_account) || @attachment.attachable.owner?(current_user)
      elsif ['Helpdesk::TicketTemplate'].include? @attachment.attachable_type
        return true if template_priv? @attachment.attachable
      end

    end

    def ticket_access?(ticket)
      return false if ticket.nil?
      (current_user && (ticket.requester_id == current_user.id || ticket.included_in_cc?(current_user.email) || 
        (current_user.company_client_manager? && current_user.company_ids.include?(ticket.company_id)) ||
        (current_user.contractor_ticket? ticket))) || 
        (params[:access_token] && ticket.access_token == params[:access_token])
    end

    def call_record_ticket
      return nil unless @attachment.attachable.respond_to?(:notable)
      @attachment.attachable.notable.respond_to?(:notable) ?
        @attachment.attachable.notable.notable : @attachment.attachable.notable
    end

end
