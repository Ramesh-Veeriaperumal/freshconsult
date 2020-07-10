class Integrations::Hootsuite::HomeController < Integrations::Hootsuite::HootsuiteController

  skip_before_filter :check_privilege, :verify_authenticity_token, :set_current_account, :check_account_state,
                     :set_time_zone, :check_day_pass_usage, :set_locale, :check_session_timeout, only: [:domain_page, :iframe_page, :plugin, :uninstall, :verify_domain, :plugin_url, :destroy]
  before_filter :update_params, :only => [:index]
  before_filter :update_redis, :only => [:search,:refresh]
  before_filter :agent_check, :filter_tickets, :only => [:index, :search, :refresh]
  skip_before_filter :authenticate_hootsuite_user, :only => [:uninstall]
  skip_before_filter :check_privilege, :only => [:agent_error]

  HOOTSUITE_FILTER = "HOOTSUITE_FILTER:%{uid}:%{pid}"
  def index
    if request.xhr? and !request.headers['X-PJAX']
      render(:partial => "ticket", :collection => @tickets)
    end
  end

  def refresh
  end

  def iframe_page
    user = hootsuite_user
    redirect_url = if user.blank?
      request.GET.merge(:action => "domain_page")
    else
      request.GET.merge(:action => 'index')
    end
    redirect_to redirect_url
  end

  def verify_domain
    redirect_url = params.merge(:action => "domain_page",:error => true)
    begin
      uri = URI.parse(params[:freshdesk_domain])
      uri = URI.parse("http://#{params[:freshdesk_domain]}") if uri.scheme.blank?
      freshdesk_domain = uri.host
      basic_auth = {:username => params[:user_session][:username], :password => params[:user_session][:password]}
      response = HTTParty.get("https://#{freshdesk_domain}#{health_check_verify_credential_path}.json",timeout: 5, :basic_auth => basic_auth)
      if response.body.include? "success"
        domain_mapping = DomainMapping.find_by_domain(freshdesk_domain)
        if domain_mapping.present?
          user_id = Sharding.select_shard_of(domain_mapping.account_id) do
              UserEmail.where(:email => params[:user_session][:username], :account_id => domain_mapping.account_id).first.user_id 
          end
          Integrations::HootsuiteRemoteUser.create!(
          :configs => {:pid => params[:pid],:freshdesk_user_id => user_id},
          :account_id => domain_mapping.account_id,
          :remote_id => params[:uid])
          action = params[:is_plugin].present? ? "handle_plugin" : "index"
          redirect_url = request.GET.merge(:action => action)
        end
      end
    rescue Exception => e
      logger.debug "#Health Check for domain #{params[:freshdesk_domain]} failed #{e}"
    ensure
      redirect_to redirect_url
    end
  end

  def destroy
    integrations_url = AppConfig['integrations_url'][Rails.env]
    Integrations::HootsuiteRemoteUser.where(:remote_id=> params[:uid]).destroy_all
    redirect_to request.GET.merge(:action => "domain_page")
  end

  def plugin
  end

  def plugin_url
    user = hootsuite_user
    redirect_url = if user.blank?
      request.GET.merge(:action => "domain_page")
    else
      request.GET.merge(:action => 'handle_plugin')
    end
    redirect_to redirect_url
  end

  def handle_plugin
     if params[:tweet_id].present?
      tweet = current_account.tweets.find_by_tweet_id(params[:tweet_id])
      ticket = tweet.get_ticket if tweet.present?
      check_already_converted(ticket)
     end

     if params[:post_id].present?
      post = current_account.facebook_posts.find_by_post_id(params[:post_id])
      ticket = post.postable if post.present?
      check_already_converted(ticket)
     end
     @item = @ticket = Helpdesk::Ticket.new
     @ticket_fields = hs_ticket_fields
  end

  def uninstall
    Integrations::HootsuiteRemoteUser.delete_all(["remote_id=?", params[:i]])
    render :nothing => true, :status => 200, :content_type => 'text/html'
  end

  def search
    render 'integrations/hootsuite/home/index'
  end

  private

  def agent_check
    render 'integrations/hootsuite/home/agent_error' and return unless current_user.agent?
  end

  def check_already_converted(ticket)
    if ticket.present?
      @path = helpdesk_ticket_url(ticket, :host => current_account.full_domain)
      render(:partial => "ticket_link_page",:locals => {:already_exist => true}) 
    end
  end

  def filter_tickets
    if current_account.launched?(:es_v2_reads)
      filter_tickets_v2
    else
      page_size = 30
      Search::EsIndexDefinition.es_cluster(current_account.id)
      items = Tire.search Search::EsIndexDefinition.searchable_aliases([Helpdesk::Ticket], current_account.id),{:load => {Helpdesk::Ticket => { :include => [{:requester => :avatar}, :ticket_states, :ticket_body, :ticket_status, :responder, :group]}},
      :size => page_size,:without_archive => true} do |tire_search|
        tire_search.query do |q|
          q.filtered do |f|
            if params[:active].present? and params[:clear].blank?
              f.query { |q| q.match :subject, SearchUtil.es_filter_key(params[:search_text], false), :analyzer => "include_stop"} if params[:search_text].present? and params[:search_type]== "keyword"
              f.filter :term, { :priority => params[:ticket_priority] } if params[:ticket_priority].present?
              f.filter :term, { :display_id => params[:search_text].to_i } if params[:search_text].present? and params[:search_type]== "ticket"
              if params[:ticket_status].present?
                f.filter :term, { :status => params[:ticket_status] }
              else
                f.filter :bool, { :must_not => {:term => { :status => Helpdesk::Ticketfields::TicketStatus::CLOSED }}} 
              end
            end
            f.filter :term, { :deleted => false }
            f.filter :term, { :spam => false }
            f.filter :term, { :responder_id => current_user.id }
            f.filter :bool, { :must_not => {:term => { :status => Helpdesk::Ticketfields::TicketStatus::CLOSED }}} if params[:active].blank? and params[:ticket_status].blank?
          end
        end
        tire_search.sort { |t| t.by('created_at','desc') }
        tire_search.from page_size * ((params[:page]||1).to_i-1)
      end
      @total_pages = items.results.total_pages
      @tickets = items.results.results.compact
    end
  end
  
  def filter_tickets_v2
    @tickets = []
    return unless params[:active].present?
    page_size   = 30
    page_offset = page_size * ((params[:page].presence || 1).to_i - 1)
		@tickets = Search::V2::QueryHandler.new({
			account_id:   current_account.id,
			context:      (params[:search_type].eql?('ticket') ? :hstickets_dispid : :hstickets_subject),
			exact_match:  false,
			es_models:    { 'ticket' => { model: 'Helpdesk::Ticket', associations: [{:requester => :avatar}, :ticket_states, :ticket_body, :ticket_status, :responder, :group]}},
			current_page: params[:page].to_i,
			offset:       page_offset,
			types:        ['ticket'],
			es_params:    (Hash.new.tap do |es_params|
				es_params[:search_term] = params[:search_text].presence
				es_params[:account_id]  = current_account.id
				es_params[:request_id]  = request.try(:uuid)
        es_params[:size]        = page_size
        es_params[:from]        = page_offset

        es_params[:agent_id]        = current_user.id
        es_params[:priority]        = params[:ticket_priority].presence
        es_params[:include_status]  = params[:ticket_status].presence
        es_params[:exclude_status]  = Helpdesk::Ticketfields::TicketStatus::CLOSED if params[:ticket_status].blank?
			end)
		}).query_results
    @total_pages = @tickets.total_pages
	end

  def update_params
    redis_filter = get_hootsuite_filter
    redis_filter = JSON.parse(redis_filter) if redis_filter.present?
    if redis_filter.present?
      params[:search_text] = redis_filter["search_text"]
      params[:search_type] = redis_filter["search_type"]
      params[:ticket_status] = redis_filter["ticket_status"]
      params[:ticket_priority] = redis_filter["ticket_priority"]
      params[:active] = redis_filter["active"] || ""
    end
  end

  def update_redis
    params[:active] = is_filter_active
    filter_hash = {
      :search_text => params[:search_text],
      :search_type => params[:search_type],
      :ticket_status => params[:ticket_status],
      :ticket_priority => params[:ticket_priority],
      :active => params[:active]
    }
    set_hootsuite_filter_key(hootsuite_filter_key, filter_hash.to_json)
  end

  def is_filter_active
    return "" if params[:clear].present?
    return "1" if params[:active].present?
    redis_filter = get_hootsuite_filter
    redis_filter = JSON.parse(redis_filter) if redis_filter.present?
    if redis_filter.present?
      return redis_filter["active"] || ""
    end
  end

  def get_hootsuite_filter
    newrelic_begin_rescue { $redis_others.get(hootsuite_filter_key) }
  end

  def hootsuite_filter_key
    HOOTSUITE_FILTER % {
      :uid => params[:uid],
      :pid => params[:pid]
    }
  end

  def set_hootsuite_filter_key(key, value)
    newrelic_begin_rescue do
      $redis_others.setex(key, 604800, value)
    end
  end

  def newrelic_begin_rescue
    begin
      yield
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
    end
  end
end
