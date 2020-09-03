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
  include DashboardControllerMethods


  UNRESOLVED_COLUMN_KEY_MAPPING = {:group_id => "group_id", :responder_id => "responder_id", :status => "status", 
      :internal_group_id => "internal_group_id", :internal_agent_id => "internal_agent_id"}

  UNRESOLVED_FILTER_HEADERS = {
      UNRESOLVED_COLUMN_KEY_MAPPING[:responder_id]      => "agent_label", 
      UNRESOLVED_COLUMN_KEY_MAPPING[:group_id]          => "group_label", 
      UNRESOLVED_COLUMN_KEY_MAPPING[:internal_agent_id] => "internal_agent_label", 
      UNRESOLVED_COLUMN_KEY_MAPPING[:internal_group_id] => "internal_group_label"
    }

  skip_before_filter :check_account_state
  before_filter :check_account_state, :redirect_to_mobile_url, :set_mobile, :show_password_expiry_warning, :only => [:index]  
  before_filter :check_dashboard_privilege, :set_ui_preference, :only => [:index]
  before_filter :set_selected_tab
  before_filter :round_robin_filter, :load_ffone_agents_by_group, :only => [:agent_status]
  around_filter :run_on_slave,            :only => [:latest_activities,:activity_list, :unresolved_tickets_data, :tickets_summary, :trend_count, :overdue, :due_today, :unresolved_tickets_dashboard, :unresolved_tickets_workload, :survey_info, :available_agents]
  before_filter :load_unresolved_filter,  :only => [:unresolved_tickets_data]
  skip_after_filter :set_last_active_time, :only => [:latest_activities]

  def index
    if request.xhr? and !request.headers['X-PJAX']
      load_items
      render(:partial => "ticket_note", :collection => @items)
    else
      render "helpdesk/realtime_dashboard/index"
    end
    #for leaderboard widget
    # @champions = champions
  end

  def show
    render "helpdesk/realtime_dashboard/index"
  end

  def activity_list
    load_items
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
    header_array = [I18n.t("unresolved_tickets.#{unresolved_ticket_headers[@group_by]}")]
    header_array << [status_list_from_cache.values, I18n.t('total')]
    header_array.flatten!
    unresolved_hash = {:data => header_array, :content => fetch_unresolved_tickets }

    render :json => {:tickets_data => unresolved_hash}.to_json
  end

  def unresolved_tickets
    @column_key_mapping = unresolved_column_key_mapping
    @status = Helpdesk::TicketStatus.status_names_from_cache(current_account)
    @groups = current_account.groups_from_cache.map { |group| [group.name, group.id] }
    @groups.insert(0,["My Groups", 0])
    @agents = current_account.agents_details_from_cache.map {|ag| [ag.name, ag.id]}
  end

  def unresolved_ticket_headers
    UNRESOLVED_FILTER_HEADERS.clone
  end

  def unresolved_column_key_mapping
    UNRESOLVED_COLUMN_KEY_MAPPING.clone
  end

  def tickets_summary
    unresolved_hash = {}
    default_trends = ["overdue", "due_today", "on_hold", "open", "unresolved", "new"]
    begin
      if current_account.dashboard_disabled?
        unresolved_hash = {:ticket_trend => {}}
      else
        default_trends.delete_if {|x| ["overdue", "due_today"].include?(x)} unless current_account.sla_management_enabled?
        trends_count_hash = ticket_trends_count(default_trends)
        unresolved_hash = {:ticket_trend => trends_count_hash}
      end
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
    @sales_manager = current_account.fresh_sales_manager_from_cache if (Rails.env.production? or Rails.env.staging?)
    render :text => I18n.t('accounts.setup.sales_manager_intro', 
      :user_name => current_user.first_name,
      :sales_manager_name => @sales_manager ? @sales_manager[:display_name] : "Bobby")
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

      unavailable_agents_list = @group.agents.pluck(:'users.id').map(&:to_s) - available_agents_list
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
    @items = recent_activities(params[:activity_id]).paginate(:page => params[:page], :per_page => 30, :total_entries => 1000)
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

  def load_unresolved_filter
    group_by_key = params[:group_by].to_sym
    column_key_mapping = unresolved_column_key_mapping
    @group_by = column_key_mapping[group_by_key] || column_key_mapping[:group_id]
    @report_type = 
        [column_key_mapping[:responder_id], column_key_mapping[:internal_agent_id]].include?(@group_by) ?
        column_key_mapping[:responder_id] : column_key_mapping[:group_id]
    @filter_condition       = {}

    column_key_mapping.keys.each do |filter|
      next unless params[filter].present?
      filter_values = params[filter].split(",")
      if filter_values.include?("0")
        filter_values.delete("0")
        filter_values.concat(user_agent_groups.map(&:to_s))
        filter_values.uniq!
      end
      instance_var = case filter
          when :internal_agent_id
            :responder_id
          when :internal_group_id
            :group_id
          else
            filter
          end

      self.instance_variable_set("@#{instance_var}", filter_values)
      @filter_condition.merge!({column_key_mapping[filter] => filter_values}) if filter_values.present?
    end
  end

  def fetch_unresolved_tickets
    es_enabled = current_account.count_es_enabled?
    #Send only column names to ES for aggregation since column names are used as keys
    options = {:group_by => [@group_by, "status"], :filter_condition => @filter_condition, :cache_data => false, :include_missing => true}
    ticket_counts = Dashboard::DataLayer.new(es_enabled,options).aggregated_data
    map_id_to_names(ticket_counts)
  end

  def ticket_trends_count(trends)
    trends.inject({}) do |type, counter_type|
      translated_key = (counter_type == "new") ? "unassigned" : counter_type
      type.merge!({:"#{counter_type}" => {:value => filter_count(counter_type.to_sym,true), :label => t("helpdesk.dashboard.summary.#{translated_key}"), :name => counter_type}})
    end
  end

  def check_dashboard_privilege
    @type = params[:view].presence || 'standard'
    access_denied if @type == "admin" and admin_dashboard_not_available?
    access_denied if @type == "supervisor" and supervisor_dashboard_not_available?
    access_denied if @type == "agent" and agent_dashboard_not_available?
    return true
  end

  def admin_dashboard_not_available?
    !current_user.privilege?(:admin_tasks)
  end

  def supervisor_dashboard_not_available?
    !(current_user.privilege?(:view_reports) and !current_user.privilege?(:admin_tasks) and current_account.launched?(:supervisor_dashboard))
  end

  def agent_dashboard_not_available?
    current_user.privilege?(:view_reports)
  end

  #### Functions for new dashboard end here
  
end
