# encoding: utf-8
class Helpdesk::AttachmentsController < ApplicationController

  include HelpdeskControllerMethods
  include Helpdesk::MultiFileAttachment::Util
  skip_before_filter :check_privilege
  before_filter :load_item, :only => [:text_content, :show, :delete_attachment]
  before_filter :check_download_permission, :only => [:show, :text_content]
  before_filter :check_destroy_permission, :only => [:destroy, :delete_attachment]
  before_filter :set_native_mobile, :only => [:show]
  before_filter :load_shared, :only => [:unlink_shared]

  def show
    style = params[:style] || "original"

    options = { secure: true, response_content_type: @attachment.content_content_type }
    options.merge!(expires_in: @attachment.expiry.to_i) if @attachment.expiry.present?
    options.merge!({ response_content_disposition: 'attachment' }) if params[:download]

    attachment_content = @attachment.content
    redirect_url = fetch_redirect_url(attachment_content.path(style.to_sym), attachment_content.bucket_name, options)

    respond_to do |format|
      
      format.html do
        redirect_to redirect_url
      end

      format.xml  do
        render :xml => @attachment.to_xml
      end

      format.json  do
        render :json => @attachment.to_json
      end

      format.nmobile do
        render :json => { "url" => redirect_url}.to_json
      end
      format.all do
        redirect_to redirect_url
      end
    end
  end

  def update
    access_denied
  end

  def text_content
    style = params[:style] || "original"
    data = AwsWrapper::S3.read(@attachment.content.bucket_name, @attachment.content.path(style.to_sym))
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
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def create_attachment    
    attachable_id = current_user.id
    @attachment = Helpdesk::Attachment.new(content: params[:file], account_id: Account.current.id, attachable_type: "UserDraft", attachable_id: attachable_id)
    if @attachment.save
      respond_to do |format|
        format.json do
          render :json => {"files" => [@attachment.to_jq_upload]}.to_json
        end
      end
    else
      if @attachment.errors && @attachment.errors.full_messages.present? && @attachment.errors.full_messages.first == "VIRUS_FOUND"
        render :json => { :errors => [t(:'multifile_attachments.virus_found_warning')] }, :status => 422
      else
        render :json => [{:error => "custom_failure"}], :status => 304
      end
    end
  end

  def delete_attachment
    if @item.destroy
      respond_to do |format|
        format.json do
          render :json => @item.to_json    
        end
      end
    else
      render :json => [{:error => "custom_failure"}], :status => 304
    end
  end

  protected

    def fetch_redirect_url(path, bucket_name, options)
      if Account.current.cdn_attachments_enabled?
        options[:expires] = options.delete(:expires_in) if options.key?(:expires_in)
        AwsWrapper::CloudFront.url_for(path, options)
      else
        AwsWrapper::S3.presigned_url(bucket_name, path, options)
      end
    end

    def load_shared
      @item = Helpdesk::SharedAttachment.where(shared_attachable_id: params[:item_id], attachment_id: params[:id]).try(:first)
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
      visible = current_account.launched?(:attachments_scope) ? @attachment.visible_to_me? : can_download?
      access_denied unless visible
    end

    def can_download?
      # Is the attachment on a note?
      #if @attachment.attachable.respond_to?(:notable)
      if ['Helpdesk::Ticket', 'Helpdesk::Note', 'Helpdesk::ArchiveTicket', 'Helpdesk::ArchiveNote', AttachmentConstants::FILE_TICKET_FIELD].include? @attachment.attachable_type

        # If the user has high enough permissions, let them download it
        return true if(current_user && current_user.agent?)

        # Or if the note belogs to a ticket, and the user is the originator of the ticket
        ticket = @attachment.attachable.respond_to?(:notable) ? @attachment.attachable.notable : @attachment.attachable
        return ticket_access? ticket

      # Is the attachment on a solution  If so, it's always downloadable.

      elsif ['Solution::Article'].include? @attachment.attachable_type
        return @attachment.attachable.solution_folder_meta.visible?(current_user)
      elsif ['Solution::Draft'].include? @attachment.attachable_type
        return current_user && current_user.privilege?(:view_solutions)
      elsif ['Post'].include? @attachment.attachable_type
        return @attachment.attachable && @attachment.attachable.forum.visible?(current_user)
      elsif ['Account', 'Portal'].include? @attachment.attachable_type
        return  true
      elsif ['DataExport'].include? @attachment.attachable_type
        return privilege?(:manage_account) || @attachment.attachable.owner?(current_user)
      elsif ['UserDraft'].include? @attachment.attachable_type
        return true if(current_user)
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
