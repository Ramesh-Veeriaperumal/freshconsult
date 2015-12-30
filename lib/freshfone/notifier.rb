class Freshfone::Notifier
  include Freshfone::NumberMethods
  include Freshfone::FreshfoneUtil
  include Freshfone::CallsRedisMethods
  include Freshfone::AgentsLoader
  include Freshfone::Endpoints
  include Freshfone::CallsRedisMethods
  include Freshfone::NodeNotifier

  attr_accessor :browser_agents, :mobile_agents, :pinged_agents, :params, :freshfone_users, :available_agents, :current_number

  def initialize(params, current_account, current_user=nil, current_number=nil)
    self.params         = params
    @current_account    = current_account
    @current_user       = current_user
    @current_number     = current_number
    @call_actions       = Freshfone::CallActions.new(params, current_account, current_number)
    @telephony          = Freshfone::Telephony.new(params, current_account, current_number)
    self.browser_agents, self.mobile_agents, self.pinged_agents = []
  end

  def notify_agents(current_call)
    load_freshfone_agents(current_call)
    notify_incoming_call(current_call) if browser_agents.any? || mobile_agents.any?
  end

  def notify_incoming_call(current_call)
    params.merge!({:freshfone_number_id => @current_number.id})
    
    if round_robin?(current_call)
      initiate_round_robin(current_call, pinged_agents)
    else
      notify_browser_agents
      notify_mobile_agents
    end
  end

  def notify_browser_agents
    if browser_agents.any?
      browser_agents.each do |agent|
        Rails.logger.debug "Triggered sidekiq notification job for browser agent #{agent} account #{@current_account.id} at #{Time.now.strftime('%H:%M:%S.%L')}"
        Freshfone::NotificationWorker.perform_async(params, agent, "browser")
      end
    end
  end

  def notify_mobile_agents
    if mobile_agents.any?
      mobile_agents.each do |agent|
        Rails.logger.debug "Triggered sidekiq notification job for mobile agent #{agent} account #{@current_account.id} at #{Time.now.strftime('%H:%M:%S.%L')}"
        Freshfone::NotificationWorker.perform_async(params, agent, "mobile")
      end
    end
  end

  def notify_transfer(current_call, target_agent_id, source_agent_id)
    params.except!(:agent, :customer)
    params.merge!({:call_id => current_call.id, :source_agent_id => source_agent_id, :transfer => 'true'})
    freshfone_user = @current_account.freshfone_users.find_by_user_id target_agent_id
    if freshfone_user.present?
      return notify_mobile_transfer(current_call, target_agent_id, source_agent_id) if freshfone_user.available_on_phone?
      Freshfone::NotificationWorker.perform_async(params, target_agent_id, "browser_transfer")
    end
  end

  def notify_group_transfer(current_call, group_id, source_agent_id)
    freshfone_users = @current_account.freshfone_users.agents_in_group(group_id).online_agents
    freshfone_users.each do |agent|
      notify_transfer(current_call, agent.user_id, source_agent_id)    
    end
  end

  def notify_external_transfer(current_call, number,source_agent_id)
    params.except!(:agent, :customer)
    params.merge!({:call_id => current_call.id, 
      :external_number => number, :source_agent_id => source_agent_id})
    Freshfone::NotificationWorker.perform_async(params, nil, "external_transfer")
  end

  def notify_mobile_transfer(current_call, agent_id, source_agent_id)
    #pass additional params if transfer is warm
    agents_list = [agent_id]
    agents_list = mobile_agents if agent_id.blank?
    params.merge!({:call_id => current_call.id, :source_agent_id => source_agent_id})
    agents_list.each do |agent|
      Freshfone::NotificationWorker.perform_async(params, agent, "mobile_transfer")
    end
  end


  def initiate_round_robin(current_call, available_agents)
      Rails.logger.debug "available_agents in initiate_round_robin => #{available_agents.inspect}"
      @current_number ||= current_call.freshfone_number
      params[:caller_id] = current_call.caller.number if params[:caller_id].blank?
      agent = available_agents.slice!(0,1)
      agent = agent.first
      params.merge!({:call_id => current_call.id})
      store_agents_in_redis(current_call, available_agents)
      if agent.present? # need to handle exception case
        Freshfone::NotificationWorker.perform_async(params, agent, "round_robin")
      end
    end

  def ivr_direct_dial(current_call)
    params.merge!({:call_id => current_call.id})
    Freshfone::NotificationWorker.perform_async(params, nil, "direct_dial")
  end

  def cancel_other_agents(current_call)
    Rails.logger.info "cancel_other_agents => #{current_call.meta.pinged_agents.to_json}"
    params.merge!({ :call_id => current_call.id })
    Freshfone::NotificationWorker.perform_async(params, nil, "cancel_other_agents")
  end

  def complete_other_agents(current_call)
    Rails.logger.info "complete_other_agents => #{current_call.meta.pinged_agents.to_json}"
    params.merge!({ :call_id => current_call.id })
    Freshfone::NotificationWorker.perform_async(params, nil, 'complete_other_agents')
  end

  def notify_source_agent_to_reconnect(call)
    if call.parent.present?
      notify_transfer_unanswered(call.parent) 
    else
      Rails.logger.error "Call parent was nil so unable to trigger reconnect event"
    end
  end

  private
    def load_freshfone_agents(current_call)
      if current_call.meta && current_call.meta.pinged_agents
        self.pinged_agents  = current_call.meta.pinged_agents.map {|agent| agent}.compact
        self.browser_agents = pinged_agents.map { |agent| agent[:id] if agent[:device_type] == :browser }.compact
        self.mobile_agents  = pinged_agents.map { |agent| agent[:id] if agent[:device_type] == :mobile }.compact
      else # Safety case
        load_available_and_busy_agents
        load_freshfone_agents(current_call)
      end
    end

    def current_account # current_account method used in freshfone_util.rb
      @current_account
    end

    def terminate_api_call(call_sid)
      call = @current_account.freshfone_subaccount.calls.get(call_sid)
      call.update(:status => "canceled")
    end

    def incoming_timeout
      @current_number.round_robin? ? 
        @current_number.rr_timeout : @current_number.ringing_time
    end

    def time_limit
      @current_account.freshfone_credit.call_time_limit
    end

    def direct_dial_time_limit
      @current_account.freshfone_credit.direct_dial_time_limit
    end

    def make_api_call(agent_id, call_params, current_call)
      agent_call = @telephony.make_call(call_params)
    end 

    def round_robin?(call)
      @current_number.round_robin? && (call.meta.simple_routing_hunt? || call.meta.group_hunt?)
    end
end