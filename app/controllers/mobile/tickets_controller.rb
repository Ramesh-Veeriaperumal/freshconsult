class Mobile::TicketsController < ApplicationController  
  include Helpdesk::TicketsHelper
  include Mobile::Controllers::Ticket
  include ActionView::Helpers::CsrfHelper
  include HelpdeskControllerMethods
  include Mobile::Constants


  before_filter :require_user_login, :set_mobile

  before_filter :set_native_mobile , :only => [:mobile_filter_count, :get_filtered_tickets, :get_solution_url, :recent_tickets]
  
  before_filter :load_ticket, :load_article , :only => [:get_solution_url]

  before_filter :validate_recent_ticket_ids, :only => [:recent_tickets]

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

  def bulk_assign_agent_list
    render :json => {:agents =>  Account.current.agents_details_from_cache.collect { |c| {:name => c.name, :id => c.id} } }
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
    respond_to do |format|
      format.nmobile {render json: counts_hash} 
    end
  end

  def get_filtered_tickets
    agent_filter = params[:agent_filter] == "true"
    params[:wf_per_page] = params[:limit].to_i > MAX_TICKET_LIMIT ? MAX_TICKET_LIMIT : params[:limit].to_i
    ticket_list = filter_tickets(agent_filter)
    tickets_json = ticket_list.map(&:to_mob_json_index)
    respond_to do |format|
      format.nmobile {render json: { tickets: tickets_json, top_view: top_view, sort_fields_options: sort_fields_options, sort_order_fields_options: sort_order_fields_options, ticket_filter_hash: ticket_filter_hash}} 
    end
  end
  
  # Commenting this method out, as none of the Mobile apps consume it anymore.
  # Confirmed this with the mobile team (Girish.K)
  # And the "solution_article_host" method in ticket model has been removed now.
  # So this action should not exist.
  # 
  # def get_solution_url
  #   respond_to do |format|
  #     format.nmobile{ 
  #       article_url = support_solutions_article_url(@article, :host => @ticket.solution_article_host(@article))
  #       render :json => { :solution_url => article_url }}
  #   end
  # end


  def recent_tickets
     Sharding.run_on_slave do
      # get all user tickets
      items = scoper.where(display_id: @tkt_ids).limit(MOBILE_RECENT_TICKETS_LIMIT)
      #filter tickets in my array
      #each_with_object insead of inject
      recent_tickets = items.inject([]) do |t, item|
        t << item.to_mob_json_index
      end
      respond_to do |format|
        format.nmobile {render json: { tickets: recent_tickets}} 
     end
    end    
  end



  private
  
  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end

  def validate_recent_ticket_ids   
    @tkt_ids = params[:recent_ticket_ids]
    #Include a count check condition here to prevent call to recent_tickets
    unless @tkt_ids.is_a?(Array) && @tkt_ids.map!(&:to_i)
     render json: { tickets: [], error: MOBILE_API_RESULT_PARAM_FAILED}
    end
  end
  
  def load_article
    @article = current_account.solution_articles.find(params[:article_id])  
  end

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

      { 
        :id => filter_id, 
        :name => filter_name, 
        :type => :view
      } 

    })
    
    #Fallback incase all custom views has 0 count..
    FILTER_NAMES.each { |view_name|
      name = t("helpdesk.tickets.views.#{view_name}")
      view_name = :all_tickets if view_name.eql?(:all)
      view_list.push( :id => view_name, :name => name, 
        :type => :filter)
    } 
    render :json => view_list.to_json
  end

  def filter_count(selector, agent_filter=false)
    if current_account.count_es_enabled?
      TicketsFilter.es_filter_count(selector, true, agent_filter)
    else
      Sharding.run_on_slave do
        tickets = filter_tickets(agent_filter,selector)
        if current_account.force_index_tickets_enabled?
          tickets.use_index("index_helpdesk_tickets_status_and_account_id").unresolved.count
        else
          tickets.unresolved.count
        end
      end
    end
  end

  def ticket_filter_hash
    if is_num?(params[:filter_name])
     {
          :order =>  @ticket_filter.data[:wf_order],
          :order_type => @ticket_filter.data[:wf_order_type]
     }
   end
  end

  def filter_tickets(agent_filter,selector = nil)
    filter_scope   = scoper
    filter_scope   = scoper.where(:responder_id => current_user.id) if agent_filter
    unless selector.nil?  
      filter_tickets = TicketsFilter.filter(filter(selector), current_user, filter_scope)
    else
      if is_num?(params[:filter_name])
        @ticket_filter = current_account.ticket_filters.find_by_id(params[:filter_name])
         
         @ticket_filter.data[:wf_order] = params[:wf_order] if params[:wf_order]
         @ticket_filter.data[:wf_order_type] = params[:wf_order_type] if params[:wf_order_type]

        @ticket_filter.query_hash = @ticket_filter.data[:data_hash]
        @ticket_filter.attributes['data']['wf_per_page'] = params[:wf_per_page]
        params.merge!(@ticket_filter.attributes["data"])
      end
      filter_tickets = filter_scope.filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
    end 
    filter_tickets
  end

  def is_num?(str)
    Integer(str.to_s)
   rescue ArgumentError
    false
   else
    true
  end

  def scoper
    current_account.tickets.permissible(current_user).preload({ticket_states: :tickets}, :account, :ticket_status, :requester, :responder, :company)
  end

  
end