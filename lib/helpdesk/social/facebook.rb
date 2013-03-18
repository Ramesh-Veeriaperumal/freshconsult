module Helpdesk::Social::Facebook
  
  ##This method can be used to send reply to facebook pvt message
  ##
  def send_facebook_message ticket = @parent, note = @item
    return_value = fb_sandbox(0) {
  	        @fb_page =  ticket.fb_post.facebook_page
		        @fb_client = FBClient.new @fb_page,{:current_account => current_account} unless @fb_page.blank?
  		      facebook = @fb_client.get_page
		        thread_id =  ticket.fb_post.thread_id
		        message = facebook.put_object(thread_id , 'messages',:message => note.body)
    	      message.symbolize_keys!
    	      process_facebook_message note , message , ticket unless message.blank?
    }
    return_value
  end

  def send_facebook_comment ticket = @parent, note = @item
    return_value = fb_sandbox(0) {
  	         @fb_page = ticket.fb_post.facebook_page
		         @fb_client = FBClient.new @fb_page,{:current_account => current_account} unless @fb_page.blank?
		         facebook = @fb_client.get_page
  		       post_id =  ticket.fb_post.post_id
		         comment = facebook.put_comment(post_id, note.body) 
		         comment.symbolize_keys!
    	       process_facebook_comment note, comment, ticket unless comment.blank?
    }
    return_value
  end

  def send_facebook_reply
    if @parent.is_fb_message?
      unless send_facebook_message 
       return flash[:notice] = @parent.fb_post.facebook_page.last_error
      end
    else
      unless send_facebook_comment 
        return flash[:notice] = @parent.fb_post.facebook_page.last_error
      end
    end
    flash[:notice] = t(:'flash.tickets.reply.success')
  end

  protected
 
  	def process_facebook_message note, facebook, ticket
  		note.create_fb_post({:post_id => facebook[:id], :facebook_page_id =>ticket.fb_post.facebook_page_id ,
  	     						 :account_id => current_account.id, :thread_id =>ticket.fb_post.thread_id , 
  	     						 													:msg_type =>'dm'})
  	end

  	def process_facebook_comment note, comment, ticket
  	  	note.create_fb_post({:post_id => comment[:id], :facebook_page_id =>ticket.fb_post.facebook_page_id ,
  	  																:account_id => current_account.id})
  	end

    def fb_sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Koala::Facebook::APIError => e
        if e.fb_error_type == 4 #error code 4 is for api limit reached
          @fb_page.attributes = {:last_error => e.to_s}
          @fb_page.save
          puts "API Limit reached - #{e.to_s}"
          NewRelic::Agent.notice_error(e, {:custom_params => {:error_type => e.fb_error_type, :error_msg => e.to_s}})
        else
          @fb_page.attributes = {:enable_page => false} if e.to_s.include?(Social::FacebookWorker::ERROR_MESSAGES[:access_token_error]) ||
                                                          e.to_s.include?(Social::FacebookWorker::ERROR_MESSAGES[:permission_error])
          @fb_page.attributes = { :reauth_required => true, :last_error => e.to_s }
          @fb_page.save
          NewRelic::Agent.notice_error(e, {:custom_params => {:error_type => e.fb_error_type, :error_msg => e.to_s, 
                                            :account_id => @fb_page.account_id, :id => @fb_page.id }})
          puts "APIError while processing facebook - #{e.to_s}"
        end
        return_value = false
      rescue Exception => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        puts "Error while processing facebook - #{e.to_s}"
      end
      return return_value
    end
end