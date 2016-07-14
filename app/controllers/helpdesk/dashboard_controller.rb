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
  include Helpdesk::TicketFilterMethods
  include Gamification::GamificationUtil

  ACTIVITY_LIMIT = {
    "type1" => 20,
    "type2" => 40,
    "type3" => 10
  }

  skip_before_filter :check_account_state
  before_filter :check_dashboard_privilege, :only => [:show]
  before_filter :check_account_state, :redirect_to_mobile_url, :set_mobile, :show_password_expiry_warning, :only => [:index]  
  before_filter :load_items, :only => [:activity_list]
  before_filter :set_selected_tab
  before_filter :round_robin_filter, :load_ffone_agents_by_group, :only => [:agent_status]
  around_filter :run_on_slave,            :only => [:unresolved_tickets_data, :tickets_summary]
  before_filter :load_unresolved_filter,  :only => [:unresolved_tickets_data]
  before_filter :load_widget_filter,      :only => [:tickets_summary]
  skip_after_filter :set_last_active_time, :only => [:latest_activities]

  def index
    if request.xhr? and !request.headers['X-PJAX']
      load_items
      render(:partial => "ticket_note", :collection => @items)
    else
      #defaulting global to be privilege based. It ll be false in show action which is 'myview'
      @manage_dashboard = current_user.privilege?(:manage_dashboard)
      @global_dashboard = true
      render "helpdesk/realtime_dashboard/index"
    end
    #for leaderboard widget
    # @champions = champions
  end

  def show
    @manage_dashboard = current_user.privilege?(:manage_dashboard)
    render "helpdesk/realtime_dashboard/index"
  end

  def activity_list
    render :partial => "activities"
  end
  
  def latest_activities
    begin
      previous_id = params[:previous_id]
      activities = Helpdesk::Activity.freshest(current_account).activity_since(previous_id).permissible(current_user).includes(:notable,{:user => :avatar}).limit(20)
      render :partial => "ticket_note", :collection => activities
    rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "Error occoured in la"})
    end
  end

  def unresolved_tickets_data
    header_array = (@group_by == "responder_id") ? ["Agent"] : ["Group"]
    header_array << [status_list_from_cache.values, "Total"]
    header_array.flatten!
    unresolved_hash = {:data => header_array, :content => fetch_unresolved_tickets }

    render :json => {:tickets_data => unresolved_hash}.to_json
  end

  def unresolved_tickets
    @status = Helpdesk::TicketStatus.status_names_from_cache(current_account)
    @groups = current_account.groups_from_cache.map { |group| [group.name, group.id] }
    @groups.insert(0,["My Groups", 0])
    @agents = current_account.agents_details_from_cache.map {|ag| [ag.name, ag.id]}
  end

  def tickets_summary
    unresolved_hash = {}
    begin
      trends_count_hash = {}
      response_hash = plan_based_widgets.inject({}) do |hash, group_by|
        tickets_count = fetch_widget_count(group_by)
        hash.merge!({"unresolved_tickets_by_#{group_by}" => id_name_mapping(tickets_count, group_by)})
      end

      unless current_account.dashboard_disabled?
        onhold_statuses  = Helpdesk::TicketStatus::onhold_statuses(current_account)
        # if response_hash["unresolved_tickets_by_status"]
        #   tickets_count    = response_hash["unresolved_tickets_by_status"]
        #   unresolved_count = tickets_count.collect {|tc| tc[:value].to_i}.sum
        #   open_count       = tickets_count.collect {|tc| tc[:value].to_i if tc[:id] == Helpdesk::Ticketfields::TicketStatus::OPEN }.compact.sum
        #   on_hold_count    = tickets_count.collect {|tc| tc[:value].to_i if onhold_statuses.include?(tc[:id])}.compact.sum
        # else
        #   tickets_count    = fetch_widget_count(:status)
        #   unresolved_count = tickets_count.values.sum
        #   open_count       = tickets_count[Helpdesk::Ticketfields::TicketStatus::OPEN].to_i
        #   on_hold_count    = onhold_statuses.collect {|st| tickets_count[st]}.compact.sum
        # end

        trends_count_hash = ticket_trends_count(["overdue", "due_today", "on_hold", "open", "unresolved", "new"])
        #trends_count_hash = ticket_trends_count(["overdue", "due_today"])
        #trends_count_hash.merge!({ :unresolved   => { :value => unresolved_count,  :label => t("helpdesk.realtime_dashboard.unresolved")} })
        #trends_count_hash.merge!({ :open         => { :value => open_count,        :label => t("helpdesk.realtime_dashboard.open") }})
        #trends_count_hash.merge!({ :on_hold      => { :value => on_hold_count,     :label => t("helpdesk.realtime_dashboard.on_hold") }})

        #trends_count_hash.merge!(ticket_trends_count(["new"])) unless current_user.assigned_ticket_permission
      end
      unresolved_hash = {:ticket_trend => trends_count_hash, :widgets => response_hash}
    rescue Exception => ex
      NewRelic::Agent.notice_error(ex)
      Rails.logger.info "Exception in Fetching tickets from DB for Dashboard, #{ex.message}, #{ex.backtrace}"
    end

    render :json => {:tickets_data => unresolved_hash}.to_json
  end

  def latest_summary
    render :partial => "summary"
  end

  def sales_manager 
    @details = current_account.fresh_sales_manager_from_cache if (Rails.env.production? or Rails.env.staging?)
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

  def achievements
    achievements_hash = {}
    if gamification_feature?(current_account)
      agent               = current_user.agent
      next_level          = agent.next_level
      next_level_name     = ""
      next_level_points   = 0  
      points_needed       = 0
      if next_level
        next_level_name     = next_level.name
        next_level_points   = next_level.points
        points_needed       = next_level_points - agent.points
      end
      achievements_hash   = {
        :points             => agent.points, 
        :current_level_name => agent.level.try(:name).to_s, 
        :next_level_name    => next_level_name, 
        :points_needed      => points_needed,
        :badges             => current_user.quests.order("achieved_quests.created_at DESC").limit(3).collect {|q| q.badge[:id]}.join(",")
      }
    end
    render :json => achievements_hash.to_json
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
        Helpdesk::Activity.freshest(current_account).activity_before(activity_id).permissible(current_user).includes(:notable,{:user => :avatar}) unless activity_id == "0"
      else
        Helpdesk::Activity.freshest(current_account).permissible(current_user).includes(:notable,{:user => :avatar})
      end
    end

  private

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
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
    @items = recent_activities(params[:activity_id]).paginate(:page => params[:page], :per_page => plan_based_count, :total_entries => 1000)
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
      @group = current_user.accessible_roundrobin_groups.find_by_id(params[:group_id])
      if @group
        set_others_redis_key(round_robin_filter_key,params[:group_id], 86400 * 7)
        @current_group_filter = params[:group_id]
      end
    else
      @current_group_filter = get_others_redis_key(round_robin_filter_key)

      if @current_group_filter
        @group = current_user.accessible_roundrobin_groups.find_by_id(@current_group_filter) 
        unless @group
          @current_group_filter = nil 
          remove_others_redis_key(round_robin_filter_key)
        end
      end
    end
    unless @group
      @group = current_user.accessible_roundrobin_groups.first
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

  #### Functions for new dashboard start here

  def load_widget_filter
    if global_dashboard? 
      if params[:group_id].present?
        @group_id         = params[:group_id].split(",")
        @filter_condition = {:group_id => @group_id} if @group_id
      end
      @group_by = params[:group_by].presence || "group_id"
    end
  end

  def load_unresolved_filter
    @group_by               = ["group_id","responder_id"].include?(params[:group_by]) ? params[:group_by] : "group_id"
    @filter_condition       = {}

    [:group_id, :responder_id, :status].each do |filter|  
      next unless params[filter].present?
      filter_values = params[filter].split(",")
      if filter_values.include?("0")
        filter_values.delete("0")
        filter_values.concat(user_agent_groups.map(&:to_s))
        filter_values.uniq!
      end
      self.instance_variable_set("@#{filter}", filter_values)
      @filter_condition.merge!({filter => filter_values}) if filter_values.present?
    end
    
  end

  def fetch_unresolved_tickets
    if current_account.launched?(:es_count_reads) || current_account.features?(:countv2_reads)
      begin
        fetch_unresolved_tickets_from_es(true)
      rescue Exception => e
        Rails.logger.info "Exception in Fetching unresolved tickets from ES for Dashboard --, #{e.message}, #{e.backtrace}"
        NewRelic::Agent.notice_error(e)
        #Fallback to DB if ES fails
        fetch_unresolved_tickets_from_db
      end
    else
      fetch_unresolved_tickets_from_db
    end
  end

  def fetch_unresolved_tickets_from_db
    begin
      ticket_counts = current_account.tickets.permissible(current_user).unresolved.visible.where(@filter_condition).group(@group_by).group(:status).count
      map_id_to_names(ticket_counts)
    rescue Exception => ex
      NewRelic::Agent.notice_error(ex)
      Rails.logger.info "Exception in Fetching tickets from DB for Dashboard, #{ex.message}, #{ex.backtrace}"
      {}
    end
  end

  def fetch_widget_count(group_by)
    tickets_count = if current_account.launched?(:es_count_reads)
      begin
        widget_count_from_es(group_by, true, !global_dashboard?)
      rescue Exception => e
        Rails.logger.info "Exception in Fetching widget count from ES for Dashboard --, #{e.message}, #{e.backtrace}"
        NewRelic::Agent.notice_error(e)
        #Fallback to DB if ES fails
        widget_count_from_db(group_by)
      end
    else
      widget_count_from_db(group_by)
    end
  end

  def widget_count_from_db(group_by)
    default_scoper.where(@filter_condition).group(group_by).count
  end

  def default_scoper
    current_account.tickets.visible.permissible(current_user).unresolved
    # if global_dashboard?
    #   current_account.tickets.visible.permissible(current_user).unresolved
    # else
    #   current_account.tickets.visible.permissible(current_user).unresolved.where(responder_id: current_user.id)
    # end
  end

  def ticket_trends_count(trends)
    trends.inject({}) do |type, counter_type|
      translated_key = (counter_type == "new") ? "unassigned" : counter_type
      type.merge!({:"#{counter_type}" => {:value => filter_count(counter_type.to_sym,true), :label => t("helpdesk.dashboard.summary.#{translated_key}"), :name => counter_type}})
    end
  end

  def filtered_trend_count(filter_type)
    action_hash = Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter_type) || []
    action_hash.push({"condition" => "group_id", "operator" => "is_in", "value" => @group_id }) if @group_id
    # unless global_dashboard?
    #   action_hash.push({"condition" => "group_id", "operator" => "is_in", "value" => user_agent_groups.join(",")}) if unassigned_filter_type?(filter_type)
    # end

    if current_account.launched?(:es_count_reads)
      #action_hash.push({"condition" => "responder_id", "operator" => "is_in", "value" => current_user.id}) if !unassigned_filter_type?(filter_type) and !global_dashboard?
      negative_conditions = [{ "condition" => "status", "operator" => "is_not", "value" => "#{RESOLVED},#{CLOSED}" }]
      Search::Filters::Docs.new(action_hash, negative_conditions).count(Helpdesk::Ticket)
    else
      filter_params = {:data_hash => action_hash.to_json}
      default_scoper.filter(:params => filter_params, :filter => 'Helpdesk::Filters::CustomTicketFilter').count
      # if unassigned_filter_type?(filter_type)
      #   current_account.tickets.visible.permissible(current_user).unresolved.filter(:params => filter_params, :filter => 'Helpdesk::Filters::CustomTicketFilter').count
      # else
      #   default_scoper.filter(:params => filter_params, :filter => 'Helpdesk::Filters::CustomTicketFilter').count
      # end
    end
  end

  def global_dashboard?
    current_user.privilege?(:manage_dashboard) && params[:global].present? 
  end

  def plan_based_widgets
    return []
    #When group id filter is present, then we group by agent for the unresolved tickets by group widget.
    widgets = current_account.features?(:custom_dashboard) ? [:status, :priority, :ticket_type] : []
    global_dashboard? ? @group_id.present? ? widgets.push(:responder_id) : widgets.push(:group_id) : widgets
  end

  def unassigned_filter_type?(filter_type)
    filter_type == "new"
  end

  def plan_based_count
    plan_name = current_account.plan_name
    plan_type = Helpdesk::DashboardHelper::PLAN_TYPE_MAPPING[plan_name]
    #plan_type = Helpdesk::DashboardHelper::ALL_WIDGET_TYPE if current_account.features?(:custom_dashboard)
    ACTIVITY_LIMIT[plan_type] || 10
  end

  def check_dashboard_privilege
    redirect_to helpdesk_formatted_dashboard_path unless current_user.privilege?(:manage_dashboard)
  end

  #### Functions for new dashboard end here
  
end
