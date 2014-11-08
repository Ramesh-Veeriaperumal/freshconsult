class ChatsController < ApplicationController
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [ :activate, :widget_activate, :site_toggle, :widget_toggle]
  before_filter  :load_ticket, :only => [:add_note]
  before_filter :verify_chat_token , :only => [:activate, :widget_activate, :site_toggle, :widget_toggle]
  
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
    agents = current_account.agents_from_cache.collect { |c| {:name=>c.user.name, :id=>c.user.id} }.to_json.html_safe
    render :json => { :agents => agents }
  end

  #######
  # This function is used to update the siteId in chat_settings table, widget_id in chat_widgets table in helpkit db, 
  # whenever chat is enabled first time for an account for.
  # Post request url :/freshchat/activate  , body : {accId : #{accId} , siteId : #{siteId} , token :#{token}, widget_id : #{widget_id} }
  #######
  def activate
    site = current_account.chat_setting
    site.update_attributes({ :active => true, :display_id => params[:site_id]})
    chat_widget = current_account.main_chat_widget
    if chat_widget.update_attributes({ :widget_id => params['widget_id'], :name => params['name']})
      render :json => { :status=> "success"}
    else
      render :json => { :status=> "error", :message => "Record Not Found"}
    end
  end

  #######
  # This function is for update the widget_id in chat_widgets table in helpkit db, 
  # whenever chat_widget for a product is created.
  # Post request url :/freshchat/widget_activate  , body : {accId : #{accId} , product_id : #{product_id} , token :#{token}, status : #{status} }
  #######

  def widget_activate
    if params[:product_id].blank?
      chat_widget = current_account.main_chat_widget
    else
      chat_widget = current_account.chat_widgets.find_by_product_id(params[:product_id])
    end
    if chat_widget
      if chat_widget.update_attributes({:active => params[:status], :widget_id => params[:widget_id]})
        if chat_widget.product && chat_widget.product.portal
          portal = chat_widget.product.portal
          Resque.enqueue(Workers::Freshchat, {
            :worker_method => "update_widget", 
            :widget_id     => chat_widget.widget_id, 
            :siteId        => current_account.chat_setting.display_id, 
            :attributes    => { 
                              :site_url => portal.portal_url
                            }
            })
        end
        render :json => {:status => "success"}
      else
        render :json => {:status => "error", :message => "Error while Updating status"}
      end
    else
      render :json => {:status => "error", :message => "Record Not Found"}
    end
  end

  #######
  # This function is used to update the Global status in chat_settings table in helpkit db, 
  # whenever chat is enabled or disable for an account.
  # Post request url :/freshchat/site_toggle  , body : {siteId : #{siteId} , status : #{status} , token :#{token}}
  #######

  def site_toggle
    site = current_account.chat_setting
    if site
      if site.update_attributes({:active => params[:status]})
        render :json => {:status => params[:status]}
      else
        render :json => {:status => "error", :message => "Error while Updating status"}
      end
    else
      render :json => {:status => "error", :message => "Record Not Found"}
    end

  end

  #######
  # This function is used to update the widget status in chat_widgets table in helpkit db, 
  # whenever widget(chat for product) is enabled or disable for an account.
  # Post request url :/freshchat/widget_toggle  , body : {widget_id : #{widget_id} , status : #{status} , token :#{token}}
  #######

  def widget_toggle
    chat_widget = current_account.chat_widgets.find_by_widget_id(params[:widget_id])
    if chat_widget
      if chat_widget.update_attributes({:active => params[:status] })
        render :json => { :status=> params[:status]}
      else
        render :json => {:status => "error", :message => "Error while Updating status"}
      end
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
    generatedToken = Digest::SHA512.hexdigest("#{ChatConfig['secret_key'][Rails.env]}::#{params['site_id']}")
    if(generatedToken != params['token'])
      Rails.logger.error('ChatsController : Authentication Failed - Invalid Token') 
      render :json => { :status=> "error", :message => "Authentication Failed"}
      return
    end
  end

end
