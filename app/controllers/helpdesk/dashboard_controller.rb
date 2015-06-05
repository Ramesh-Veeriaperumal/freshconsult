class Helpdesk::DashboardController < ApplicationController

  helper  Helpdesk::TicketsHelper #by Shan temp
  include Reports::GamificationReport
  include Cache::Memcache::Account
  include Redis::RedisKeys
  include Redis::OthersRedis

  skip_before_filter :check_account_state
  before_filter :check_account_state, :only => [:index]
  before_filter :redirect_to_mobile_url, :only=>[:index] 
  before_filter :set_mobile, :only => [:index]
  
  before_filter :load_items, :only => [:activity_list]
  before_filter :set_selected_tab
  before_filter :round_robin_filter, :only => [:agent_status]

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
  
  def latest_summary
    render :partial => "summary"
  end

  def sales_manager 
    @details = current_account.sales_manager_from_cache if Rails.env.production?
    render :partial => "sales_manager"
  end

  def agent_status
    load_ticket_assignment if current_account.features?(:round_robin)
    load_freshfone if current_account.features?(:ffone_agent_availability) 
    respond_to do |format|
      format.html # index.html.erb
      format.js do 
        render :agent_status, :formats => [:rjs]
      end
    end
  end

  def load_ffone_agents_by_group 
    @group = current_account.groups.find_by_id(params[:group_id])
    @agent_ids = @group.agents.inject([]){ |result, agent| result << agent.id }
    render :json => { :id => @agent_ids }
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

end
