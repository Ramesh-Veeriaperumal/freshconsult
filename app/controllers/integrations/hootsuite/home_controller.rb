class Integrations::Hootsuite::HomeController < Integrations::Hootsuite::HootsuiteController

  skip_before_filter :check_privilege, :verify_authenticity_token, :set_current_account,:check_account_state,
   :set_time_zone, :check_day_pass_usage, :set_locale, :only => [:domain_page, :iframe_page, :plugin, :uninstall, :verify_domain, :delete_hootsuite_user]
  before_filter :agent_check, :filter_tickets, :only => [:index, :search]
  skip_before_filter :authenticate_hootsuite_user, :only => [:uninstall,:delete_hootsuite_user]
  skip_before_filter :check_privilege, :only => [:hootsuite_login, :create_login_session, :log_out, :agent_error]

  def index
    if request.xhr? and !request.headers['X-PJAX']
      render(:partial => "ticket", :collection => @tickets)
    end
  end

  def iframe_page
    user = hootsuite_user
    redirect_url = if user.blank?
      request.GET.merge(:action => "domain_page")
    else
      domain = DomainMapping.main_portal.find_by_account_id(user.account_id).domain
      request.GET.merge(:host => domain,:action => 'index')
    end
    redirect_to redirect_url
  end

  def verify_domain
    redirect_url = params.merge(:action => "domain_page",:error => true)
    begin
      uri = URI.parse(params[:freshdesk_domain])
      uri = URI.parse("http://#{params[:freshdesk_domain]}") if uri.scheme.blank?
      freshdesk_domain = uri.host
      response = HTTParty.get("https://#{freshdesk_domain}#{health_check_verify_domain_path}.json",timeout: 5)
      if response.body.include? "success"
        domain_mapping = DomainMapping.find_by_domain(freshdesk_domain)
        if domain_mapping.present?
          Integrations::HootsuiteRemoteUser.create(
          :configs => {:pid => params[:pid]},
          :account_id => domain_mapping.account_id,
          :remote_id => params[:uid])
          domain = DomainMapping.main_portal.find_by_account_id(domain_mapping.account_id).domain
          redirect_url = request.GET.merge(:controller => "home",:host => domain,:action => "hootsuite_login")
        end
      end
    rescue Exception => e
      logger.debug "#Health Check for domain #{params[:freshdesk_domain]} failed #{e}"
    ensure
      redirect_to redirect_url
    end
  end

  def create_login_session
    @user_session = current_account.user_sessions.new(params[:user_session])
    if @user_session.save
      @current_user_session = @user_session
      @current_user = @user_session.record
      render 'integrations/hootsuite/home/agent_error' and return unless @current_user.agent?
      redirect_back_or_default(params.merge(:action => "index")) if grant_day_pass
    else
      # redirect_to(:back)
      @error = true
      render :hootsuite_login
    end
  end

  def destroy
    clear_cookies
    integrations_url = AppConfig['integrations_url'][Rails.env]
    HTTParty.delete(integrations_url+integrations_hootsuite_home_delete_hootsuite_user_path+"?uid="+params[:uid])
    redirect_to request.GET.merge(:host => URI.parse(integrations_url).host, :controller => "home", :action => "domain_page")
  end

  def delete_hootsuite_user
    Integrations::HootsuiteRemoteUser.delete_all(["remote_id=?", params[:uid]])
    render :json => { :success => true }
  end

  def plugin
   user = hootsuite_user
     if user.present?
      @freshdesk_domain = DomainMapping.find_by_account_id(user.account_id).domain and return
    else
      render :text => 'User not logged in to hootsuite' and return
    end
  end

  def log_out
    clear_cookies
    redirect_to(params.merge(:controller => "home", :action => "index"))
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

  def clear_cookies
    cookies.delete 'user_credentials'     
    current_user_session.destroy unless current_user_session.nil?
    @current_user_session = @current_user = nil
  end

  def agent_check
    render 'integrations/hootsuite/home/agent_error' and return unless current_user.agent?
  end

  def check_already_converted(ticket)
    if ticket.present?
      @path = helpdesk_ticket_url(ticket)
      render(:partial => "ticket_link_page",:locals => {:already_exist => true}) 
    end
  end

  def filter_tickets
    page_size = 10
    Search::EsIndexDefinition.es_cluster(current_account.id)
    items = Tire.search Search::EsIndexDefinition.searchable_aliases([Helpdesk::Ticket], current_account.id),{:load => {Helpdesk::Ticket => { :include => [{:requester => :avatar}, :ticket_states, :ticket_old_body, :ticket_status, :responder, :group]}},
    :size => page_size,:without_archive => true} do |tire_search|
      tire_search.query do |q|
        q.filtered do |f|
          f.query { |q| q.match :subject, SearchUtil.es_filter_key(params[:search_text], false), :analyzer => "include_stop"} if params[:search_text].present? and params[:search_type]== "keyword"
          f.filter :term, { :responder_id => current_user.id }
          if params[:ticket_status].present? and params[:search_type]== "filter"
            f.filter :term, { :status => params[:ticket_status] }
          else
            f.filter :bool, { :must_not => {:term => { :status => Helpdesk::Ticketfields::TicketStatus::CLOSED }}} 
          end
          f.filter :term, { :priority => params[:ticket_priority] } if params[:ticket_priority].present? and params[:search_type]== "filter"
          f.filter :term, { :display_id => params[:search_text].to_i } if params[:search_text].present? and params[:search_type]== "ticket"
          f.filter :term, { :deleted => false }
          f.filter :term, { :spam => false }
        end
      end
      tire_search.sort { |t| t.by('created_at','desc') }
      tire_search.from page_size * ((params[:page]||1).to_i-1)
    end
    @total_pages = items.results.total_pages
    @tickets = items.results.results.compact
  end
end
