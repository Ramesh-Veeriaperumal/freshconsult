class Helpdesk::AttachmentsController < ApplicationController
  
  include HelpdeskControllerMethods
 

  #before_filter :check_download_permission, :only => [:show]

  def show
    
     #result =  Net::HTTP.get_response(URI.parse(@attachment.content.url))
     
    
      #redirect_to( @attachment.content.expiring_url(60))
      #redirect_to AWS::S3::S3Object.url_for(@attachment.content_file_name,@attachment.content.bucket_name)
      #redirect_to @attachment.content.expiring_url(60) #by Shan tem, need to check this '60'
      
      #render :nothing => true
      redir_url = AWS::S3::S3Object.url_for(@attachment.content.path,@attachment.content.bucket_name,:expires_in => 10.seconds)
      redirect_to( redir_url.gsub( AWS::S3::DEFAULT_HOST, '' ))
  end
  
   def fetch_url(url)
    r = Net::HTTP.get_response(URI.parse(url))
    if r.is_a? Net::HTTPSuccess
      r.body
    else
      nil
    end
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
      elsif ['Account'].include? @attachment.attachable_type
        return true
      end 
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
    end
  
end
