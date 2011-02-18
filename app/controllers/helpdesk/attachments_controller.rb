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
        return true if params[:access_token] && ticket.access_token == params[:access_token]
  
      # Is the attachment on a guide? If so, it's always downloadable.
      # elsif @attachment.attachable.guide
      #   return  true
      end 
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
    end
  
#    def is_the_requester?
#      if @attachment.attachable.respond_to?(:notable)
#        return true if current_user && @attachment.attachable.notable.requester_id == current_user.id
#        return true if params[:access_token] && @attachment.attachable.notable.access_token == params[:access_token]
#      end
#      
#      return true if current_user && @attachment.attachable.requester_id == current_user.id
#      return true if params[:access_token] && @attachment.attachable.access_token == params[:access_token]
#    end
end
