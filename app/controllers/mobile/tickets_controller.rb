class Mobile::TicketsController < ApplicationController  
  include Helpdesk::TicketsHelper
  include Mobile::Controllers::Ticket
  include ActionView::Helpers::CsrfHelper
  include HelpdeskControllerMethods

  before_filter :require_user_login, :set_mobile
  
  FILTER_NAMES = [ :new_and_my_open, :all, :monitored_by, :spam, :deleted ]
  
  MOBILE_FILTERS = [ :overdue, :due_today, :on_hold, :open, :new ]

  MAX_TICKET_LIMIT = 60

  def view_list
    agent_view_list
  end

  def get_portal
    #do it in better way..
    # mob_json = current_account.to_mob_json(current_user.agent?)[0..-2]+","+current_user.to_mob_json[1..-1]
    mob_json = {};
    mob_json.merge!(current_account.to_mob_json(current_user.agent?));
    mob_json.merge!(current_user.to_mob_json);
    mob_json.merge!(current_portal.to_mob_json);
    cookies[:csrf_token] = form_authenticity_token if mobile?
    render :json => mob_json
  end

  def ticket_properties
	render :json => ticket_props
  end

  def load_reply_emails
    reply_emails = current_account.features?(:personalized_email_replies) ? current_account.reply_personalize_emails(current_user.name) : current_account.reply_emails
    render :json => reply_emails
  end

  def mobile_filter_count
    agent_filter = params[:agent_filter] == "true"
    counts_hash  = {}
    MOBILE_FILTERS.each do |element|
      counts_hash[element] = {
        :count => filter_count(element, (element != :new && agent_filter))
      }
    end
    render :json => counts_hash
  end

  def get_filtered_tickets
    agent_filter = params[:agent_filter] == "true"
    selector = params[:filter_name].to_sym 
    from_display_id = params[:display_id].to_i
    limit = params[:limit].to_i > MAX_TICKET_LIMIT ? MAX_TICKET_LIMIT : params[:limit].to_i
    order_type = ["DESC","ASC"].include?(params[:order_type]) ? params[:order_type] : "ASC" 
    ticket_set = filter_tickets(selector, agent_filter).mobile_filtered_tickets(from_display_id,limit,"created_at #{order_type}") 
    tickets_json = ticket_set.map(&:to_mob_json_index)
    render :json => { :tickets => tickets_json, :top_view => top_view }
  end

  private

  # possible dead code
  def customer_view_list
    view_list = []
    CUSTOMER_FILTER_NAMES.each { |view_name|
      count = TicketsFilter.filter(view_name.to_sym, current_user, current_user.tickets).size
      view_list.push( 
        :id => view_name, 
        :name => t("helpdesk.tickets.views.#{view_name}"), 
        :type => :filter, 
        :count =>  count
      )
    }

    CUSTOMER_FILTER_NAMES.each { |view_name|
      count = TicketsFilter.filter(view_name.to_sym, current_user, current_user.company.tickets).size
      view_list.push(
        :company => current_user.company.name, 
        :id => view_name.to_s+' ', 
        :name => t("helpdesk.tickets.views.#{view_name}"), 
        :type => :filter, 
        :count =>  count
      )
    } if current_user.is_client_manager

    render :json => view_list.to_json
  end

  def agent_view_list
    #Loading custom views
    view_list = []
    views = current_account.ticket_filters.my_ticket_filters(current_user)
    view_list.concat( views.map { |view| 
      view.deserialize_from_params(view.data)
      filter_id = view[:id]
      filter_name = view[:name]
      joins = view.get_joins(view.sql_conditions)
      options = { :joins => joins, :conditions => view.sql_conditions, :select => :id}
      options[:distinct] = true if view.sql_conditions[0].include?("helpdesk_tags.name")
      ticket_count =  current_account.tickets.permissible(current_user).count(options)

      { 
        :id => filter_id, 
        :name => filter_name, 
        :type => :view, 
        :count=> ticket_count
      } 

    })
    
    #Fallback incase all custom views has 0 count..
    FILTER_NAMES.each { |view_name|
      count = filter_count(view_name)
      name = t("helpdesk.tickets.views.#{view_name}")
      view_name = :all_tickets if view_name.eql?(:all)
      view_list.push( :id => view_name, :name => name, 
        :type => :filter, :count => count )
    } 
    render :json => view_list.to_json
  end

  def filter_count(selector, agent_filter=false)
    Sharding.run_on_slave do
      tickets = filter_tickets(selector, agent_filter)
      tickets.count
    end
  end

  def filter_tickets(selector, agent_filter)
    filter_scope = current_account.tickets.permissible(current_user)
    filter_scope = filter_scope.where(:responder_id => current_user.id) if agent_filter
    filter_tickets = TicketsFilter.filter(filter(selector), current_user, filter_scope)
    filter_tickets
  end

end
