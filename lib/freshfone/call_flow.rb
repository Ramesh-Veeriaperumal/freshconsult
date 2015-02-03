class Freshfone::CallFlow
  include Freshfone::FreshfoneHelper
  include Redis::RedisKeys
  include Redis::IntegrationsRedis
  include Freshfone::CallsRedisMethods
  include Freshfone::CallValidator
	BEYOND_THRESHOLD_PARALLEL_INCOMING = 3 # parallel incomings allowed beyond safe_threshold
	BEYOND_THRESHOLD_PARALLEL_OUTGOING = 1 # parallel incomings allowed beyond safe_threshold
  
  attr_accessor :available_agents, :busy_agents, :params, :current_account, :current_number,
                :current_user, :welcome_menu, :call_initiator, :transfered,
                :outgoing_transfer, :call_actions, :numbers, :hunt_options
  delegate :record?, :non_business_hour_calls?, :ivr, :direct_dial_limit, :to => :current_number
  delegate :freshfone_users, :to => :current_account
	delegate :read_welcome_message, :to => :ivr
  delegate :connect_caller_to_agent, :add_caller_to_queue, :block_incoming_call,
          :initiate_recording, :initiate_voicemail, :initiate_outgoing, :connect_caller_to_numbers,
          :return_non_availability, :return_non_business_hour_call, :make_transfer_to_agent, 
          :dial_to_agent_group, :to => :call_initiator
  delegate :register_call_transfer, :register_incoming_call, :register_outgoing_call, :register_blocked_call,
           :register_direct_dial, :save_call_meta, :register_group_call_transfer, :to => :call_actions

  def initialize(params={}, current_account=nil, current_number=nil, current_user=nil)
    self.params = params
    self.hunt_options = {}
    self.current_account = current_account
    self.current_number = current_number
    self.current_user = current_user
    self.call_initiator = Freshfone::CallInitiator.new(params, current_account, current_number, self)
    self.call_actions = Freshfone::CallActions.new(params, current_account, current_number)
  end

  def resolve_request
    return reject_twiml if cannot_connect_call?
    return initiate_recording if params[:record]
    return trigger_ivr_flow if params[:preview]
    return outgoing if outgoing?
    blacklisted? ? block_call : incoming_or_ivr
  end

  def incoming
    if available_agents.any?
      connect_caller_to_agent
    elsif all_agents_busy?
      add_caller_to_queue(hunt_options)
    else 
      return_non_availability
    end  
  end
  
  def call_users_in_group(performer_id)
    load_users_from_group(performer_id)
    incoming
  end

  def call_user_with_id(performer_id, freshfone_user=nil)
    set_direct_dial_agent(performer_id)
    find_user_with_id(performer_id, freshfone_user)
    set_hunt_options(:agent, performer_id)
    incoming
  end
  
  def call_user_with_number(number)
    if !authorized_country?(number,current_account)
      set_restricted_status
      return reject_twiml  
    end
    return initiate_voicemail if direct_dialled_number_busy?(number)
    register_direct_dial(number)
    self.numbers = [number]
    connect_caller_to_numbers
  end
  
  def trigger_ivr_flow
    Freshfone::IvrMethods.trigger_ivr_flow(params, current_account, current_number, self)
  end
  
  def transfer(agent, current_user_id, outgoing = false)
    self.outgoing_transfer = outgoing
    self.transfered = true
    params.merge!({:source_agent => current_user_id, :outgoing => self.outgoing_transfer})
    find_user_with_id(params[:id], agent.freshfone_user)
    make_transfer_to_agent(params[:id])
  end

  def transfer_to_group(agents, current_user_id, outgoing = false)
    self.outgoing_transfer = outgoing
    self.transfered = true
    params.merge!({:source_agent => current_user_id, :outgoing => self.outgoing_transfer})
    register_group_call_transfer(outgoing)
    return dial_to_agent_group(agents, false)
  end
  
  def dequeue(agent)
    if agent 
      find_user_with_id(agent)
    else
      load_available_and_busy_agents
    end
    self.call_initiator.queued = true
    connect_caller_to_agent
  end

  private

    def outgoing
      return reject_twiml unless register_outgoing_device
      register_outgoing_call
      initiate_outgoing
    end

    def block_call
      register_blocked_call
      block_incoming_call
    end

    def incoming_or_ivr
      register_incoming_call
      return return_non_business_hour_call unless working_hours?
      ivr.ivr_message? ? trigger_ivr_flow : regular_incoming
    end

    def regular_incoming
      load_available_and_busy_agents
      incoming
    end

    def set_hunt_options(type, performer)
      self.hunt_options = {
        :type => type,
        :performer => performer.to_s
      }
    end

    def set_direct_dial_agent(agent_id)
      return if params[:CallSid].blank?
      call = current_account.freshfone_calls.find_by_call_sid(params[:CallSid]) 
      call.user_id = agent_id
      call.save
    end

    def direct_dialled_number_busy?(number)
      busy_dd_calls = current_account.freshfone_calls.active_calls.find_all_by_direct_dial_number(number)
      busy_dd_calls.count >= direct_dial_limit
    end

    def all_agents_busy?
      available_agents.empty? and busy_agents.any?
    end

    def working_hours?
      (non_business_hour_calls? or within_business_hours?)
    end

    def within_business_hours?
     default_business_calendar = current_number.business_calendar 
     default_business_calendar.blank? ? (default_business_calendar = Freshfone::Number.default_business_calendar(current_number)) :
          (Time.zone = default_business_calendar.time_zone)  
     business_hours = Time.working_hours?(Time.zone.now,default_business_calendar)
    ensure
      TimeZone.set_time_zone
    end

    def outgoing?
      params[:To].blank?
    end

    def set_restricted_status
      return if params[:CallSid].blank?
      call = current_account.freshfone_calls.find_by_call_sid(params[:CallSid]) 
      call.update_status({:DialCallStatus => "restricted"})
      call.save
    end

    def blacklisted?
      current_account.freshfone_blacklist_numbers.find_by_number(params[:From].gsub(/^\+/, ''))
    end

    def find_user_with_id(performer_id, freshfone_user=nil)
      freshfone_user = freshfone_users.find_by_user_id(performer_id) if freshfone_user.blank?
      self.available_agents = freshfone_user && freshfone_user.online? ? [freshfone_user] : []
      self.busy_agents = freshfone_user && freshfone_user.busy? ? [freshfone_user] : []
    end

    def load_available_and_busy_agents
      return load_users_from_group(current_number.group_id) if current_number.group.present?
      load_all_available_and_busy_agents
    end

    def load_users_from_group(performer_id)
      self.available_agents = online_agents.agents_in_group(performer_id)
      self.busy_agents = freshfone_users.busy_agents_in_group(performer_id)
      save_call_meta(performer_id)
      set_hunt_options(:group, performer_id)
    end

    def load_all_available_and_busy_agents
      self.available_agents = online_agents
      self.busy_agents = freshfone_users.busy_agents
    end

    def online_agents
      sort_order = current_number.round_robin? ?  "ASC" : "DESC"
      freshfone_users.agents_by_last_call_at(sort_order)
    end

    def cannot_connect_call?
      return true if current_account.freshfone_credit.below_safe_threshold?
      return true if outgoing? && !authorized_country?(params[:PhoneNumber],current_account)
      return outgoing? ? outgoing_limit_reached? : incoming_limit_reached?
      false
    end

    def calls_count
      @calls_count ||= begin
        key = FRESHFONE_CALLS_BEYOND_THRESHOLD % { :account_id => current_account.id }
        get_key(key).to_i
      end
    end

    def outgoing_limit_reached?
      (calls_count & 15) >= BEYOND_THRESHOLD_PARALLEL_OUTGOING
    end

    def incoming_limit_reached?
      (calls_count >> 4) >= BEYOND_THRESHOLD_PARALLEL_INCOMING
    end

    def register_outgoing_device
      agent_user_id = split_client_id(params[:From])
      return true if set_outgoing_device([agent_user_id])
      agent_progress_calls?(agent_user_id).blank?
    end

    def agent_progress_calls?(agent_user_id)
      Freshfone::Call.agent_progress_calls(agent_user_id).first
    end
end