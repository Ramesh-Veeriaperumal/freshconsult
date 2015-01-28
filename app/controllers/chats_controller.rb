class ChatsController < ApplicationController

  include ChatHelper
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [ :activate, :widget_activate, :site_toggle, :widget_toggle, :chat_note]
  before_filter :verify_chat_token , :only => [:activate, :widget_activate, :site_toggle, :widget_toggle, :chat_note]
  before_filter  :load_ticket, :only => [:add_note, :chat_note]
 
  def index
    if chat_activated?
      widget_values = current_account.chat_widgets.reject{|c| c.widget_id ==nil}.collect {|c| [c.widget_id,(c.product.blank? ? current_account.name : c.product.name)]}
      @selected_tab = :dashboard
      @widgets = widget_values.map{ |i| [i[0], i[1]] }.to_h.to_json.html_safe
      @widgetsSelectOption = widget_values.map{ |i| [i[1], i[0]] }
      @agentsAvailable = current_account.agents_from_cache.collect { |c| [c.user.name, c.user.id] }
      @dateRange = "#{30.days.ago.strftime("%d %b, %Y")} - #{0.days.ago.strftime("%d %b, %Y")}"
    else
      render_404
    end
  end

  
  def create_ticket
    ticket_params = {
                      :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:chat],
                      :email  => params[:ticket][:email],
                      :subject  => params[:ticket][:subject],
                      :requester_name => params[:ticket][:name],
                      :ticket_body_attributes => { :description_html => params[:ticket][:content] }
                    }
    widget = current_account.chat_widgets.find_by_widget_id(params[:ticket][:widget_id])
    group = current_account.groups.find_by_id(params[:ticket][:group_id]) if params[:ticket][:group_id]
    ticket_params[:product_id] = widget.product.id if widget.product
    ticket_params[:group_id] = group.id if group

    @ticket = current_account.tickets.build(ticket_params) 
    status = @ticket.save_ticket

    render :json => { :ticket_id=> @ticket.display_id , :status => status }
  end

  def groups
    groups = []
    groups.push([ t("freshchat.everyone"), 0 ])
    groups.concat(current_account.groups.collect{|c| [c.name, c.id]})
    render :json => {:groups => groups.to_json}
  end

  def add_note 
    params[:userId] = current_user.id
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
    if chat_widget.update_attributes({ :widget_id => params['widget_id']})
      create_widget_for_product
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
          Resque.enqueue(Workers::Livechat, 
            {
              :worker_method => "update_widget", 
              :widget_id     => chat_widget.widget_id, 
              :siteId        => current_account.chat_setting.display_id, 
              :attributes    => { :site_url => portal.portal_url }
            }
          )
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

  #######
  # This function is used to add note to ticket
  # Post request url :/freshchat/chat_note  , body : {ticket_id : #{ticket_id} , msg : #{msg} , userId :#{userId}}
  #######

  def chat_note
    status = create_note
    render :json => { :ticket_id=> @note.notable.display_id , :status => status }
  end

  def visitor
    @selected_tab = :dashboard
  end

  private
  
  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end
  
  def create_note 
    @note = @ticket.notes.build(
                :private => false,
                :user_id => params[:userId],
                :account_id => current_account.id,
                :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                :note_body_attributes => { :body_html => params[:note] }
            )
    @note.save_note
  end

  def verify_chat_token
    generatedToken = Digest::SHA512.hexdigest("#{ChatConfig['secret_key']}::#{params['site_id']}")
    if(generatedToken != params['token'])
      Rails.logger.error('ChatsController : Authentication Failed - Invalid Token') 
      render :json => { :status=> "error", :message => "Authentication Failed"}
      return
    end
  end

  def create_widget_for_product
    products = current_account.products
    unless products.blank?
      products.each do |product|
        if product.chat_widget.blank?
          product.build_chat_widget
          product.chat_widget.account_id = current_account.id
          product.chat_widget.chat_setting_id = current_account.chat_setting.id
          product.chat_widget.main_widget = false
          product.chat_widget.show_on_portal = false
          product.chat_widget.portal_login_required = false
          product.chat_widget.name = product.name
          product.chat_widget.save
        end
      end
    end
  end


end
