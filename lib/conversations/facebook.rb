module Conversations::Facebook
  def send_facebook_reply
    if @parent.is_fb_message?
      fb_reply = add_facebook_reply
      unless fb_reply.blank?
        fb_reply.symbolize_keys!
        @item.create_fb_post({:post_id => fb_reply[:id], :facebook_page_id =>@parent.fb_post.facebook_page_id ,:account_id => current_account.id,
                              :thread_id =>@parent.fb_post.thread_id , :msg_type =>'dm'})
      end
    else
      fb_comment = add_facebook_comment
      unless fb_comment.blank?
        fb_comment.symbolize_keys!
        @item.create_fb_post({:post_id => fb_comment[:id], :facebook_page_id =>@parent.fb_post.facebook_page_id ,:account_id => current_account.id})
      end
    end
  end

  def add_facebook_comment
    fb_page =  @parent.fb_post.facebook_page
    unless fb_page.nil?
      begin 
        @fb_client = FBClient.new fb_page,{:current_account => current_account}
        facebook_page = @fb_client.get_page
        post_id =  @parent.fb_post.post_id
        comment = facebook_page.put_comment(post_id, @item.body) 
      rescue => e
        fb_page.update_attributes({ :reauth_required => true, :last_error => e.message})
        flash[:notice] = e.message
        return nil
      end
    end
  end

  #This method can be used to send reply to facebook pvt message
  def add_facebook_reply
    fb_page =  @parent.fb_post.facebook_page
    unless fb_page.blank?
      begin 
        @fb_client = FBClient.new fb_page,{:current_account => current_account}
        facebook_page = @fb_client.get_page
        thread_id =  @parent.fb_post.thread_id
        reply = facebook_page.put_object(thread_id , 'messages',:message => @item.body)
      rescue => e
        fb_page.update_attributes({ :reauth_required => true, :last_error => e.message})
        flash[:notice] = e.message
        return nil
      end
    end
  end
  
end