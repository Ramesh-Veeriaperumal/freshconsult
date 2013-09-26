# encoding: utf-8
class Helpdesk::AttachmentsController < ApplicationController
  
  include HelpdeskControllerMethods
  skip_before_filter :check_privilege
  before_filter :check_download_permission, :only => [:show]  
  before_filter :check_destroy_permission, :only => [:destroy]
  before_filter :set_native_mobile, :only => [:show]
  def show
    style = params[:style] || "original"
    redir_url = AwsWrapper::S3Object.url_for(@attachment.content.path(style.to_sym),@attachment.content.bucket_name,
                                          :expires => 300.seconds, :secure => true)
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
    end
  end
  
  def scoper
    current_account.attachments
  end 

  def load_item
    @attachment = @item = scoper.find(params[:id])

    @item || raise(ActiveRecord::RecordNotFound)
  end
  
  

  protected
  
     def check_destroy_permission
      can_destroy = false
      
      @items.each do |attachment|
        if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? attachment.attachable_type
          ticket = attachment.attachable.respond_to?(:notable) ? attachment.attachable.notable : attachment.attachable
          can_destroy = true if privilege?(:manage_tickets) or (current_user && ticket.requester_id == current_user.id)
        elsif ['Solution::Article'].include? attachment.attachable_type
          can_destroy = true if privilege?(:publish_solution) or (current_user && attachment.attachable.user_id == current_user.id)
        elsif ['Account'].include? attachment.attachable_type
          can_destroy = true if privilege?(:manage_account)
        elsif ['Post'].include? attachment.attachable_type
          can_destroy = true if privilege?(:edit_topic) or (current_user && attachment.attachable.user_id == current_user.id)
        elsif ['User'].include? attachment.attachable_type
          can_destroy = true if privilege?(:manage_users) or (current_user && attachment.attachable.id == current_user.id)
        end
      end
      
          unless  can_destroy
            flash[:notice] = t(:'flash.general.access_denied')
            redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
          end
      
      
     
   end
   

    def check_download_permission      
      access_denied unless can_download?      
    end

    def can_download?

      # Is the attachment on a note?
      #if @attachment.attachable.respond_to?(:notable)
      if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? @attachment.attachable_type
  
        # If the user has high enough permissions, let them download it
        return true if(current_user && current_user.agent?)
  
        # Or if the note belogs to a ticket, and the user is the originator of the ticket
        ticket = @attachment.attachable.respond_to?(:notable) ? @attachment.attachable.notable : @attachment.attachable
        return (current_user && (ticket.requester_id == current_user.id || ticket.included_in_cc?(current_user.email) || 
          (privilege?(:client_manager)  && ticket.requester.customer == current_user.customer))) || 
          (params[:access_token] && ticket.access_token == params[:access_token])
  
      # Is the attachment on a solution  If so, it's always downloadable.

      elsif ['Solution::Article'].include? @attachment.attachable_type
        return @attachment.attachable.folder.visible?(current_user) 
      elsif ['Post'].include? @attachment.attachable_type      
        return @attachment.attachable.forum.visible?(current_user)     
      elsif ['Account', 'Portal'].include? @attachment.attachable_type
        return  true     
      elsif ['DataExport'].include? @attachment.attachable_type
        return true if privilege?(:manage_account)
      end         

    end
  
end
