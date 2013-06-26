module Social::TwitterUtil

def add_tweet_as_ticket twt , twt_handle , twt_type
     
    ticket = @account.tickets.build(
      :subject => twt.text,
      :twitter_id => @sender.screen_name,
      :product_id => twt_handle.product_id,
      :group_id => ( twt_handle.product ? twt_handle.product.primary_email_config.group_id : nil) ,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :created_at => Time.zone.at(twt.created_at),
      :tweet_attributes => {:tweet_id => twt.id,  
                            :tweet_type => twt_type.to_s, :twitter_handle_id => twt_handle.id},
      :ticket_body_attributes => { :description => twt.text } )
      
      if ticket.save
        puts "This ticket has been saved"
      else
        puts "error while saving the ticket:: #{ticket.errors.to_json}"
      end
  end
  
  def get_user(screen_name)
    user = @account.all_users.find_by_twitter_id(screen_name)
    unless user
      user = @account.contacts.new
      user.signup!({:user => {:twitter_id => screen_name, :name => screen_name, 
                    :active => true,
                    :helpdesk_agent => false}})
      end
     user
  end
  
  def add_tweet_as_note twt,twt_handle, twt_type , ticket
    
      note = ticket.notes.build(
        :note_body_attributes => {:body => twt.text},
        :incoming => true,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
        :account_id => twt_handle.account_id,
        :user_id => @user.id ,
        :created_at => Time.zone.at(twt.created_at),
        :tweet_attributes => {:tweet_id => twt.id,
                              :tweet_type => twt_type.to_s, :twitter_handle_id => twt_handle.id}
       )
      if note.save
        puts "This note has been added"
      else
        puts "error while saving the ticket:: #{note.errors.to_json}"
      end
  end
  

end