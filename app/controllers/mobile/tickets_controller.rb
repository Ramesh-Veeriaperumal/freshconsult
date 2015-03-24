class Mobile::TicketsController < ApplicationController  
  include Helpdesk::TicketsHelper
  include Mobile::Controllers::Ticket
  include ActionView::Helpers::CsrfHelper

  before_filter :require_user_login, :set_mobile
  
  FILTER_NAMES = [ :new_and_my_open, :all, :monitored_by, :spam, :deleted ]
  

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

end
