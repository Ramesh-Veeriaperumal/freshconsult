class Helpdesk::DashboardController < ApplicationController
  helper  Helpdesk::TicketsHelper #by Shan temp

  include Freshfone::FreshfoneUtil
  include Reports::GamificationReport
  include Cache::Memcache::Account
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Helpdesk::Ticketfields::TicketStatus
  include Dashboard::ElasticSearchMethods
  include Dashboard::UtilMethods

  skip_before_filter :check_account_state
  before_filter :check_account_state, :only => [:index]
  before_filter :redirect_to_mobile_url, :only=>[:index] 
  before_filter :set_mobile, :only => [:index]
  before_filter :show_password_expiry_warning, :only => [:index]
  
  before_filter :load_items, :only => [:activity_list]
  before_filter :set_selected_tab
  before_filter :round_robin_filter, :only => [:agent_status]
  before_filter :load_ffone_agents_by_group, :only => [:agent_status]
  around_filter :run_on_slave, :only => [:unresolved_tickets_data]
  before_filter :load_filter_params, :only => [:unresolved_tickets_data]
  skip_after_filter :set_last_active_time, :only => [:latest_activities]

  def index
    if request.xhr? and !request.headers['X-PJAX']
      load_items
      render(:partial => "ticket_note", :collection => @items)
    end
    #for leaderboard widget
    # @champions = champions
  end

  def activity_list
    render :partial => "activities"
  end
  
  def latest_activities
    begin
      previous_id = params[:previous_id]
      activities = Helpdesk::Activity.freshest(current_account).activity_since(previous_id).permissible(current_user).limit(20)
      render :partial => "ticket_note", :collection => activities
    rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "Error occoured in la"})
    end
  end

  def unresolved_tickets_data
    if current_account.launched?(:es_count_reads)
      begin
        response = fetch_tickets_from_es(true)
      rescue Exception => e
        Rails.logger.info "Exception in Fetching tickets from ES for Dashboard --, #{e.message}, #{e.backtrace}"
        NewRelic::Agent.notice_error(e)
        #Fallback to DB if ES fails
        response = fetch_tickets_from_db
      end
    else
      response = fetch_tickets_from_db
    end
    header_array = (@group_by == "responder_id") ? ["Agent"] : ["Group"]
    header_array << [status_list_from_cache.values, "Total"]
    header_array.flatten!
    unresolved_hash = {:data => header_array, :content => response }

    render :json => {:tickets_data => unresolved_hash}.to_json
  end

  def unresolved_tickets
    @status = Helpdesk::TicketStatus.status_names_from_cache(current_account)
    @groups = current_account.groups_from_cache.map { |group| [group.name, group.id] }
    @groups.insert(0,["My Groups",0])
    @agents = current_account.agents_from_cache.map {|ag| [ag.user.name, ag.user_id]}
  end

  def latest_summary
    render :partial => "summary"
  end

  def sales_manager 
    @details = current_account.sales_manager_from_cache if Rails.env.production?
    render :partial => "sales_manager"
  end

  def agent_status
    load_ticket_assignment if current_account.features?(:round_robin)
    load_freshfone if view_context.freshfone_active?
    load_livechat_groups if current_account.features?(:chat)
    respond_to do |format|
      format.html # index.html.erb
      format.js do 
        render :agent_status, :formats => [:rjs]
      end
    end
  end

  def load_ffone_agents_by_group 
    if params[:freshfone_group_id].present?
      if (params[:freshfone_group_id]==Freshfone::Number::ALL_NUMBERS) 
        set_others_redis_key(freshfone_filter_key,params[:freshfone_group_id], 86400 * 7)
        render :json => { :id => Freshfone::Number::ALL_NUMBERS }
      else  
        @freshfone_group = current_account.groups.find_by_id(params[:freshfone_group_id])
        @agent_ids = @freshfone_group.agents.inject([]){ |result, agent| result << agent.id }
        render :json => { :id => @agent_ids }
        if @freshfone_group
           set_others_redis_key(freshfone_filter_key,params[:freshfone_group_id], 86400 * 7)
        end
      end  
    else
        @freshfone_group_current= get_others_redis_key(freshfone_filter_key) 
        if @freshfone_group_current
          @freshfone_group = current_account.groups.find_by_id(@freshfone_group_current)  
        end  

    end   
  end 

  protected
    def recent_activities(activity_id)
      if activity_id
        Helpdesk::Activity.freshest(current_account).activity_before(activity_id).permissible(current_user) unless activity_id == "0"
      else
        Helpdesk::Activity.freshest(current_account).permissible(current_user)
      end
    end

  private

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end 

  def load_filter_params
    @group_by = params[:group_by].presence || "group_id"
    @filter_condition = {}
    @user_agent_groups = user_agent_groups
    dashboard_redis_filter = {}
    [:group_id, :responder_id, :status].each do |filter|
      next unless params[filter].present?
      filter_value = params[filter].split(",")
      if filter_value.include?("0")
        filter_value.delete("0")
        filter_value.concat(@user_agent_groups)
        filter_value.uniq!
      end
      self.instance_variable_set('@' + filter.to_s, filter_value)
      @filter_condition.merge!({filter => filter_value}) if filter_value.present?
      dashboard_redis_filter.merge!(filter => params[filter])
    end
    if @filter_condition.present?
      set_others_redis_key(dashboard_redis_key, dashboard_redis_filter.to_json)
    else
      remove_others_redis_key(dashboard_redis_key)
    end
  end

    def load_ticket_assignment
      all_agents = {}

      if @current_group_filter
        available_agents_list = @group.round_robin_queue.reverse

        unavailable_agents_list = @group.agents.all(:select => "users.id").map(&:id).map(&:to_s) - available_agents_list
        agent_ids = available_agents_list + unavailable_agents_list
        all_agents = current_account.agents.where(user_id: agent_ids).includes([{:user => :avatar}]).reorder("field(user_id, #{agent_ids.join(',')})").group_by(&:available) if agent_ids.any?
      end

      @available_agents   = all_agents[true] || []
      @unavailable_agents = all_agents[false] || []
    end

    def load_freshfone
       @freshfone_agents = current_account.freshfone_users.agents_with_avatar
    end

    def load_livechat_groups
       groups = current_account.groups.includes(:agent_groups)
       @groupOptions = groups.collect{|c| [c.name, c.id]}
       @groupOptions.insert(0,[ t("helpdesk.dashboard.livechat.select_by_group"), "disabled"])
       @agents_in_groups = Hash[*groups.collect{|g| [g.id, {:name => g.name, :users => g.agent_groups.map(&:user_id)}]}.flatten].to_json.html_safe
    end

    def load_items
      @items = recent_activities(params[:activity_id]).paginate(:page => params[:page], :per_page => 10, :total_entries => 1000)
    end

    def recent_activity_id
      shard = Thread.current[:shard_selection].shard
      RECENT_ACTIVITY_IDS[shard] || 1
    end
    
    def set_selected_tab
      @selected_tab = :dashboard
    end

    def round_robin_filter
      if params[:group_id].present?
        @group = current_account.groups.find_by_id(params[:group_id])
        if @group
          set_others_redis_key(round_robin_filter_key,params[:group_id], 86400 * 7)
          @current_group_filter = params[:group_id]
        end
      else
        @current_group_filter = get_others_redis_key(round_robin_filter_key)

        if @current_group_filter
          @group = current_account.groups.round_robin_groups.find_by_id(@current_group_filter) 
          unless @group
            @current_group_filter = nil 
            remove_others_redis_key(round_robin_filter_key)
          end
        end
      end
      unless @group
        @group = current_account.groups.round_robin_groups.first
        if @group
          @current_group_filter = @group.id 
          set_others_redis_key(round_robin_filter_key,@group.id, 86400 * 7)
        end
      end
    end

    def round_robin_filter_key
      ADMIN_ROUND_ROBIN_FILTER % {:account_id => current_account.id, :user_id => current_user.id}
    end
    
    def freshfone_filter_key
      ADMIN_FRESHFONE_FILTER % {:account_id => current_account.id, :user_id => current_user.id}
    end

  def fetch_tickets_from_db
    begin
      ticket_response = current_account.tickets.permissible(current_user).unresolved.where(spam:false, deleted:false).where(@filter_condition).group(@group_by).group(:status).count
      map_id_to_names(ticket_response)
    rescue Exception => ex
      NewRelic::Agent.notice_error(ex)
      Rails.logger.info "Exception in Fetching tickets from DB for Dashboard, #{ex.message}, #{ex.backtrace}"
      return {}
    end
  end

  def dashboard_redis_key
    key = { 
              :account_id => current_account.id,
              :user_id => current_user.id
            }
    DASHBOARD_TABLE_FILTER_KEY % key
  end
end
