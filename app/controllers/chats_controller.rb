class ChatsController < ApplicationController
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:chatEnable, :chatToggle]
  before_filter  :load_ticket, :only => [:add_note]
  before_filter :verify_chat_token , :only => [:chatEnable, :chatToggle]
  
  def create_ticket

    @ticket = current_account.tickets.build(
                  :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:chat],
                  :email  => params[:ticket][:email],
                  :subject  => params[:ticket][:subject],
                  :requester_name => params[:ticket][:name],
                  :ticket_body_attributes => { :description_html => params[:ticket][:content] }
              ) 

    status = @ticket.save_ticket

    render :json => { :ticket_id=> @ticket.display_id , :status => status }

  end  

  def add_note 
    
    status = create_note
    render :json => { :ticket_id=> @note.notable.display_id , :status => status }

  end

  def agents

    agents = Base64.strict_encode64(current_account.agents_from_cache.collect { |c| {:name=>c.user.name, :id=>c.user.id} }.to_json.html_safe )
    render :json => { :agents => agents }

  end

  #######
  # This function is used to update the siteId in chat_settings table in helpkit db, 
  # whenever chat feature is enabled first time for an account for.
  # Post request url :/freshchat/chatenable  , body : {accId : #{accId} , siteId : #{siteId} , token :#{token} }
  #######
  def chatEnable

    reqRow = ChatSetting.find(:first, :conditions => [ "account_id = ?", params['accId']])

    if(reqRow)
      status = reqRow.update_attributes({ :active => 1, :display_id => params['siteId'] })
      reqRow.save
      render :json => { :status=> status}
    else
      render :json => { :status=> "error", :message => "Record Not Found"}
    end

  end

  #######
  # This function is used to update the chat status in chat_settings table in helpkit db, 
  # whenever chat is enabled or disable for an account.
  # Post request url :/freshchat/chattoggle  , body : {siteId : #{siteId} , status : #{status} , token :#{token}}
  #######

  def chatToggle
    
    reqRow = ChatSetting.find(:first, :conditions => [ "display_id = ?", params['siteId']])
    puts "Request Row ---------#{reqRow}"
    if(reqRow)
      status = reqRow.update_attributes({:active => params["status"]})
      reqRow.save
      render :json => {:status => status}
      puts "STATUS _-------- #{status}"
    else
      render :json => {:status => "error", :message => "Record Not Found"}
    end

  end


  private
  
  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end
  
  def create_note 
    @note = @ticket.notes.build(
                :private => false,
                :user_id => current_user.id,
                :account_id => current_account.id,
                :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                :note_body_attributes => { :body_html => params[:note] }
            )
    @note.save_note
  end

  def verify_chat_token
    
    generatedToken = Digest::SHA512.hexdigest("#{ChatConfig['secret_key'][Rails.env]}::#{params['siteId']}")
    
    if(generatedToken != params['token'])
      Rails.logger.error('ChatsController : Authentication Failed - Invalid Token') 
      
      render :json => { :status=> "error", :message => "Authentication Failed"}
      
      return
    end

  end

end
