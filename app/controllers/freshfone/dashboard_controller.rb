class Freshfone::DashboardController < ApplicationController
  include Redis::RedisKeys
  include Redis::IntegrationsRedis
  include Freshfone::NodeEvents
  include Freshfone::CallHistory

  before_filter :load_stats_count, :only => [:dashboard_stats]
  skip_after_filter :set_last_active_time, :only => [:dashboard_stats]

  def index
    @freshfone_active_calls = get_active_calls
    @queued_calls = get_queued_calls
  end

  def dashboard_stats
    render :json => { 
                      :available_agents => @available_agents,
                      :busy_agents => @busy_agents,
                      :active_calls_count => @active_calls_count,
                      :queued_calls_count => @queued_calls_count
                   }
  end

  def calls_limit_notificaiton
    notify_live_dashboard_calls_count_exceeded(params[:call_type])
    render :json => {:result =>  true}
  end

  def mute
     begin 
      if current_call.inprogress?
        telephony.mute_supervisor(current_call, params[:isMute])
        render :json => {:result =>  :true}
      else
        render :json => {:result =>  :error}
      end
     rescue Exception => e
       Rails.logger.error "Error in Muting Supervisor | CallSid: #{params[:CallSid]} :: #{current_account.id} \n #{e.message}\n #{e.backtrace.join("\n\t")}"  
       render :json => {:result => :exception}
     end
  end

  private
    def freshfone_user_scoper
      current_account.freshfone_users
    end

    def freshfone_calls_scoper
      current_account.freshfone_calls
    end
  
  def load_stats_count
      Sharding.run_on_slave do
        @available_agents = freshfone_user_scoper.online_agents.count
        @busy_agents = freshfone_user_scoper.busy_agents.count
        @active_calls_count = freshfone_calls_scoper.active_calls.count
        @queued_calls_count = freshfone_calls_scoper.queued_calls.count
      end
    end

    def get_active_calls
      Sharding.run_on_slave do
        freshfone_calls_scoper.active_calls
      end
    end

    def get_queued_calls
      Sharding.run_on_slave do
        freshfone_calls_scoper.queued_calls
      end
    end

    def notify_live_dashboard_calls_count_exceeded(call_type)
      FreshfoneNotifier.freshfone_email_template(current_account,{
          :recipients => FreshfoneConfig['ops_alert']['mail']['to'],
          :from       => FreshfoneConfig['ops_alert']['mail']['from'],
          :subject    => "Dashboard calls count exceeds the limit",
          :message    => "#{call_type} calls count exceeds the limit for Account :: #{(current_account || {})[:id]} <br>"})
    end

    def telephony
      current_number ||= current_call.freshfone_number
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
    end



end