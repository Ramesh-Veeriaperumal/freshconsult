class Helpdesk::AttachmentsController < ApplicationController
  
  include HelpdeskControllerMethods
 

  before_filter :check_download_permission, :only => [:show]
  
  before_filter :check_destroy_permission, :only => [:destroy]

  def show
    
      redir_url = AWS::S3::S3Object.url_for(@attachment.content.path,@attachment.content.bucket_name,:expires_in => 300.seconds)
      redirect_to(  redir_url.gsub( "#{AWS::S3::DEFAULT_HOST}/", '' ))
  end
  
  def scoper
    current_account.attachments
  end 
  
  

  protected
  
     def check_destroy_permission
      can_destroy = false
      
      @items.each do |attachment|
        if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? attachment.attachable_type
          ticket = attachment.attachable.respond_to?(:notable) ? attachment.attachable.notable : attachment.attachable
          can_destroy = true if permission?(:manage_tickets) or (current_user && ticket.requester_id == current_user.id)
        elsif ['Solution::Article'].include? attachment.attachable_type
          can_destroy = true if permission?(:manage_knowledgebase) or (current_user && attachment.attachable.user_id == current_user.id)
        elsif ['Account'].include? attachment.attachable_type
          can_destroy = true if permission?(:manage_users)
        elsif ['Post'].include? attachment.attachable_type
          can_destroy = true if permission?(:manage_forums) or (current_user && attachment.attachable.user_id == current_user.id)
        elsif ['User'].include? attachment.attachable_type
          can_destroy = true if permission?(:manage_users) or (current_user && attachment.attachable.id == current_user.id)
        end
      end
      
          unless  can_destroy
            flash[:notice] = "You are not allowed access this page !"   
            redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
          end
      
      
     
   end
   

    def check_download_permission
  
      # Is the attachment on a note?
      #if @attachment.attachable.respond_to?(:notable)
      if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? @attachment.attachable_type
  
        # If the user has high enough permissions, let them download it
        return true if permission?(:manage_tickets)
  
        # Or if the note belogs to a ticket, and the user is the originator of the ticket
        ticket = @attachment.attachable.respond_to?(:notable) ? @attachment.attachable.notable : @attachment.attachable
        return true if current_user && ticket.requester_id == current_user.id
  
      # Is the attachment on a solution  If so, it's always downloadable.
      
      elsif ['Solution::Article'].include? @attachment.attachable_type      
        return  true     
      elsif ['Account'].include? @attachment.attachable_type
        return true
      elsif ['Post'].include? @attachment.attachable_type
        return true
      elsif ['DataExport'].include? @attachment.attachable_type
        return true if permission?(:manage_users)
      end 
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
    end
  
end
