class Freshfone::CallFlow
  include FreshfoneHelper
  include Redis::RedisKeys
  include Redis::IntegrationsRedis
	BEYOND_THRESHOLD_PARALLEL_INCOMING = 3 # parallel incomings allowed beyond safe_threshold
	BEYOND_THRESHOLD_PARALLEL_OUTGOING = 1 # parallel incomings allowed beyond safe_threshold
  
  attr_accessor :available_agents, :busy_agents, :params, :current_account, :current_number,
                :current_user, :welcome_menu, :call_initiator, :transfered,
                :outgoing_transfer, :call_actions, :numbers, :hunt_options
  delegate :record?, :non_business_hour_calls?, :ivr, :to => :current_number
  delegate :freshfone_users, :to => :current_account
	delegate :read_welcome_message, :to => :ivr
  delegate :connect_caller_to_agent, :add_caller_to_queue, :block_incoming_call,
          :initiate_recording, :initiate_voicemail, :initiate_outgoing, :connect_caller_to_numbers,
          :return_non_availability, :return_non_business_hour_call, :to => :call_initiator
  delegate :register_call_transfer, :register_incoming_call, :register_outgoing_call, :register_blocked_call,
           :register_direct_dial, :to => :call_actions

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
    find_user_with_id(performer_id, freshfone_user)
    set_hunt_options(:agent, performer_id)
    incoming
  end
  
  def call_user_with_number(number)
    return initiate_voicemail if direct_dialled_number_busy?(number)
    register_direct_dial(number)
    self.numbers = [number]
    connect_caller_to_numbers
  end
  
  def trigger_ivr_flow
    Freshfone::IvrMethods.trigger_ivr_flow(params, current_account, current_number, self)
  end
  
  def transfer(agent, outgoing=false)
    self.outgoing_transfer = outgoing
    self.transfered = true
    register_call_transfer(outgoing_transfer)
    call_user_with_id(params[:id], agent.freshfone_user)
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

    def direct_dialled_number_busy?(number)
      calls_today = current_account.freshfone_calls.active_calls
      calls_today.each do |call|
        return true if call.direct_dial_number == number
      end
      false
    end

    def all_agents_busy?
      available_agents.empty? and busy_agents.any?
    end

    def working_hours?
      (non_business_hour_calls? or within_business_hours?)
    end

    def within_business_hours?
      Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD] = current_number
      Time.zone = current_number.business_calendar.time_zone unless current_number.business_calendar.blank?
      business_hours = Time.working_hours?(Time.zone.now)
      Thread.current[TicketConstants::BUSINESS_HOUR_CALLER_THREAD] = nil 
      business_hours
    ensure
      TimeZone.set_time_zone
    end

    def outgoing?
      params[:To].blank?
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
      self.available_agents = freshfone_users.online_agents_in_group(performer_id)
      self.busy_agents = freshfone_users.busy_agents_in_group(performer_id)
      set_hunt_options(:group, performer_id)
    end

    def load_all_available_and_busy_agents
      self.available_agents = freshfone_users.online_agents
      self.busy_agents = freshfone_users.busy_agents
    end

    def cannot_connect_call?
      return false unless current_account.freshfone_credit.below_safe_threshold?
      outgoing? ? outgoing_limit_reached? : incoming_limit_reached?
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
end