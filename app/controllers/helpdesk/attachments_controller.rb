class Helpdesk::AttachmentsController < ApplicationController

  include HelpdeskControllerMethods

  before_filter :check_download_permission, :only => [:show]

  def show
      #    send_file(
      #      @attachment.content.path, 
      #      :type => @attachment.content_content_type,
      #      :filename => @attachment.content_file_name
      #    )
      
      #redirect_to(AWS::S3::S3Object.url_for(@attachment.content.path, @attachment.content.bucket_name, :expires_in => 10.seconds))
      redirect_to @attachment.content.expiring_url(60) #by Shan tem, need to check this '60'
  end

  protected

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
      end 
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
    end
  
end
