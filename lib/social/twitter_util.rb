module Social::TwitterUtil

  def add_as_ticket(twt, twt_handle, twt_type, gnip=false)
    tkt_hash = construct_params(twt,gnip) 
    
    ticket = @account.tickets.build(
      :subject =>  Helpdesk::HTMLSanitizer.plain(tkt_hash[:body]) ,
      :twitter_id =>  tkt_hash[:sender] ,
      :product_id => twt_handle.product_id,
      :group_id => ( twt_handle.product ? twt_handle.product.primary_email_config.group_id : nil) ,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :created_at =>  tkt_hash[:posted_time] ,
      :tweet_attributes => {
        :tweet_id => tkt_hash[:tweet_id] ,
        :tweet_type => twt_type.to_s,
        :twitter_handle_id => twt_handle.id
      },
      :ticket_body_attributes => {
        :description_html => tkt_hash[:body] 
      }
    )

    if ticket.save_ticket
      puts "This ticket has been saved"
    else
      NewRelic::Agent.notice_error("Error in converting a tweet to ticket", :custom_params => 
        {:error_params => ticket.errors.to_json})
      puts "error while saving the ticket:: #{ticket.errors.to_json}"
    end
  end


  def add_as_note(twt,twt_handle, twt_type, ticket, gnip=false)
    note_hash = construct_params(twt,gnip)
    
    note = ticket.notes.build(
      :note_body_attributes => {
        :body_html => note_hash[:body]
      },
      :incoming => true,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :account_id => twt_handle.account_id,
      :user_id => @user.id,
      :created_at => note_hash[:posted_time],
      :tweet_attributes => {
        :tweet_id => note_hash[:tweet_id] ,
        :tweet_type => twt_type.to_s,
        :twitter_handle_id => twt_handle.id
      }
    )
    begin
      @user.make_current
      if note.save_note
        puts "This note has been added"
      else
        NewRelic::Agent.notice_error("Error in converting a tweet to ticket", :custom_params => 
          {:error_params => note.errors.to_json})
        puts "error while saving the ticket:: #{note.errors.to_json}"
      end
    ensure
      User.reset_current_user
    end
  end


  def get_twitter_user(screen_name, profile_image_url=nil) 
    user = @account.all_users.find_by_twitter_id(screen_name)
    unless user
      user = @account.contacts.new
      user.signup!({
        :user => {
          :twitter_id => screen_name,
          :name => screen_name,
          :active => true,
          :helpdesk_agent => false
        }
      })
    end
    if user.avatar.nil? && !profile_image_url.nil?
      args = {:account_id => @account.id,
              :twitter_user_id => user.id,
              :prof_img_url => profile_image_url}
      Resque.enqueue(Social::UploadAvatarWorker, args)
    end
    user
  end

  def construct_params(twt,gnip)
    hash = {
      :body => gnip ? twt[:body] : twt.text,
      :tweet_id => gnip ? twt[:id].split(":").last.to_i : twt.id ,
      :posted_time => gnip ? Time.at(Time.parse(twt[:postedTime]).to_i) : Time.at(twt.created_at).utc,
      :sender => gnip ? @sender : @sender.screen_name
    }
  end
end