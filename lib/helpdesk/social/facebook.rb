module Helpdesk::Social::Facebook
  
  ##This method can be used to send reply to facebook pvt message
  ##
  def send_facebook_message ticket = @parent, note = @item
  	fb_page =  ticket.fb_post.facebook_page
  	begin
		@fb_client = FBClient.new fb_page,{:current_account => current_account} unless fb_page.blank?
  		facebook = @fb_client.get_page
		thread_id =  ticket.fb_post.thread_id
		message = facebook.put_object(thread_id , 'messages',:message => note.body)
    	message.symbolize_keys!
    	process_facebook_message note , message , ticket unless message.blank?
    rescue => e
    	fb_page.update_attributes({ :reauth_required => true, :last_error => e.message})
    	return false
    end
    return true
  end

  def send_facebook_comment ticket = @parent, note = @item
  	fb_page = ticket.fb_post.facebook_page
  	begin
		@fb_client = FBClient.new fb_page,{:current_account => current_account} unless fb_page.blank?
		facebook = @fb_client.get_page
  		post_id =  ticket.fb_post.post_id
		comment = facebook.put_comment(post_id, note.body) 
		comment.symbolize_keys!
    	process_facebook_comment note, comment, ticket unless comment.blank?
    rescue => e
    	fb_page.update_attributes({ :reauth_required => true, :last_error => e.message})
    	return false
    end
    return true
  end

  def send_facebook_reply
    if @parent.is_fb_message?
      unless send_facebook_message 
        flash[:notice] = @parent.fb_post.facebook_page.last_error
      end
    else
      unless send_facebook_comment 
        flash[:notice] = @parent.fb_post.facebook_page.last_error
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
end