class Freshfone::CallFlow
  include FreshfoneHelper
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  
  attr_accessor :available_agents, :busy_agents, :params, :current_account, :current_number,
                :current_user, :welcome_menu, :call_initiator, :transfered,
                :outgoing_transfer, :call_actions, :numbers, :hunt_options
  delegate :record?, :non_business_hour_calls?, :ivr, :to => :current_number
  delegate :freshfone_users, :to => :current_account
	delegate :read_welcome_message, :to => :ivr
  delegate :connect_caller_to_agent, :add_caller_to_queue, :initiate_voicemail, :block_incoming_call,
          :initiate_recording, :initiate_outgoing, :connect_caller_to_numbers, :to => :call_initiator
  delegate :register_call_transfer, :register_incoming_call, :register_outgoing_call, :register_blocked_call,
           :to => :call_actions

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
    return initiate_recording if params[:record]
    return trigger_ivr_flow if params[:preview]
    return outgoing if outgoing?
    blacklisted? ? block_call : incoming_or_ivr
  end

  def incoming
    transfered ? register_call_transfer(outgoing_transfer) : register_incoming_call
    if available_agents.any?
      connect_caller_to_agent
    elsif all_agents_busy?
      add_caller_to_queue(hunt_options)
    else 
      initiate_voicemail('offline')
    end  
  end
  
  def outgoing
    register_outgoing_call
    return initiate_outgoing
  end

  def block_call
    register_blocked_call
    return block_incoming_call
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
    self.numbers = [number]
    register_incoming_call
    connect_caller_to_numbers
  end
  
  def trigger_ivr_flow
    Freshfone::IvrMethods.trigger_ivr_flow(params, current_account, current_number, self)
  end
  
  def transfer(agent, outgoing=false)
    self.outgoing_transfer = outgoing
    self.transfered = true
    call_user_with_id(params[:id], agent.freshfone_user)
  end
  
  def dequeue(agent)
    if agent 
      find_user_with_id(agent)
    else
      load_available_and_busy_agents
    end
    connect_caller_to_agent
  end

  private

    def set_hunt_options(type, performer)
      self.hunt_options = {
        :type => type,
        :performer => performer.to_s
      }
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

    def incoming_or_ivr
      return non_business_hour_call unless working_hours?
      ivr.ivr_message? ? trigger_ivr_flow : regular_incoming
    end
    
    def regular_incoming
      load_available_and_busy_agents
      incoming
    end

    def non_business_hour_call
      register_incoming_call
      initiate_voicemail('non_business_hours')
    end

    def outgoing?
      params[:To].blank?
    end

    def blacklisted?
      # blacklist = current_account.freshfone_blacklist_numbers.all(:select => 'number').map(&:number)
      # blacklist.include? params[:From]
      current_account.freshfone_blacklist_numbers.find_by_number(params[:From])
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

end