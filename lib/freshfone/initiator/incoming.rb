class Freshfone::Initiator::Incoming
  include Freshfone::SubscriptionsUtil
  include Freshfone::FreshfoneUtil
  include Freshfone::CallValidator
  include Freshfone::Endpoints
  include Freshfone::AgentsLoader
  include Freshfone::CallsRedisMethods
  include Freshfone::NumberMethods

  def self.match?(params)
    (params[:type] == "incoming") || (params[:type] == "agent_leg")
  end

  attr_accessor :params, :current_account, :current_number, :current_call, :freshfone_users,
                :available_agents, :busy_agents, :routing_type

  delegate :non_business_hour_calls?, :ivr, :direct_dial_limit, :to => :current_number

  def initialize(params, current_account, current_number)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.freshfone_users = current_account.freshfone_users
    @call_actions        = Freshfone::CallActions.new(params, current_account, current_number)
  end

  def process
    return preview_ivr if params[:preview]
    return agent_call_leg.process if agent_leg_of_incoming?
    return block_call if blacklisted?
    return handle_unauthorized_call if from_unauthorized_number?
    
    self.current_call ||= @call_actions.register_incoming_call
    return telephony.return_non_business_hour_call if current_number.present? && !current_number.working_hours?
    ivr.ivr_message? ? trigger_ivr_flow : regular_incoming
  end

  def process_ivr
    trigger_ivr_flow
  end

  def regular_incoming
    load_available_and_busy_agents
    process_incoming
  end

  def process_incoming
    if available_agents.any?
      initiate_incoming
    elsif all_agents_busy?
      initiate_queue
    else 
      return_non_availability
    end 
  end

  def initiate_incoming
    telephony.initiate_customer_conference({ :wait_url => wait_url, :available_agents => get_pinged_agents }, true)
  end

  def initiate_queue(type=:initiated)
    # self.current_call.queued! # SpreadsheetL 45
    current_call = current_account.freshfone_calls.find_by_call_sid params[:CallSid]
    queue_disabled_or_overloaded? ? return_non_availability : telephony.initiate_queue(type)
  end

  def resolve_simultaneous_call_queue(simultaneous_call)
    simultaneous_call ? telephony.initiate_re_queue : telephony.initiate_queue
  end

  def return_non_availability(welcome_message = true)
    current_call ||= current_account.freshfone_calls.find_by_call_sid(params[:CallSid])
    current_call.update_missed_abandon_status unless (current_call.present? && current_number.voicemail_active)
    telephony.return_non_availability(welcome_message)
  end

  def call_users_in_group(group_id)
    load_group_hunt_agents(group_id)
    process_incoming
  end

  def call_user_with_id(agent_id, freshfone_user=nil)
    load_agent(agent_id, freshfone_user)
    process_incoming
  end

  def call_user_with_number(number)
    return restricted_call('Trial Restriction') if trial?
    return restricted_call if !authorized?(number)
    return return_non_availability(false) if direct_dialled_number_busy?(number)

    current_call = @call_actions.register_direct_dial(number)
    telephony.initiate_customer_conference({ :wait_url => direct_dial_wait_url }, true)
  end

  def dequeue(agent_id)
    load_agent agent_id
    telephony.initiate_customer_conference({
      :wait_url => wait_url
    })
  end

  def block_call
    @call_actions.register_blocked_call
    telephony.block_incoming_call
  end

  def restricted_call(reason = nil)
    @call_actions.set_status_restricted
    telephony.reject(reason)
  end

  private
    def trigger_ivr_flow
      Freshfone::IvrMethods.trigger_ivr_flow(params, current_account, current_number, self)
    end

    def agent_call_leg
      Freshfone::Initiator::AgentCallLeg.new(params, current_account, current_number, @call_actions, telephony)
    end

    def agent_leg_of_incoming?
      params[:type] == "agent_leg" || params[:caller_sid].present?
    end    

    def blacklisted?
      current_account.freshfone_blacklist_numbers.find_by_number(params[:From].gsub(/^\+/, ''))
      current_caller = current_account.freshfone_callers.find_by_number(params[:From])
      return if current_caller.blank?
      current_caller.blocked?
    end

    def all_agents_busy?
      available_agents.empty? and busy_agents.any?
    end 

    def authorized?(number)
      authorized_country?(number, current_account)
    end

    def direct_dialled_number_busy?(number)
      busy_dd_calls = current_account.freshfone_calls.active_calls.find_all_by_direct_dial_number(number)
      busy_dd_calls.count >= direct_dial_limit
    end

    def incoming_timeout
      timeout = current_number.round_robin? ? 
        (current_number.rr_timeout*available_agents.length) : current_number.ringing_time
    end

    def preview_ivr
      register_ivr_preview
      trigger_ivr_flow
    end

    def get_pinged_agents
      return if current_call.blank?
      call_meta = current_call.meta
      return if call_meta.blank? || call_meta.pinged_agents.blank?
      call_meta.pinged_agents
    end

    def queue_disabled_or_overloaded?
      return true if queue_disabled?
      queue_sid = current_account.freshfone_account.queue
      queue = current_account.freshfone_subaccount.queues.get(queue_sid)
      queue.present? and (queue.current_size >= max_queue_size)
    end

    def telephony
      current_call ||= current_account.freshfone_calls.find_by_call_sid(params[:CallSid])
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number, current_call)
    end

    def from_unauthorized_number?
      UNAUTHORISED_NUMBERS_LIST.any? { |num| params[:From].ends_with?(num)}
    end

    def handle_unauthorized_call
      Rails.logger.info "Call from spam number. Account ID::#{current_account.id} CallSid:: #{params[:CallSid]}"
      message = "Account #{current_account.id} is using spam numbers."
      notification = "Call from spam number"
      FreshfoneNotifier.deliver_ops_alert(current_account, notification, message)
      suspend_account_and_block_call
    end

    def suspend_account_and_block_call
      begin
        current_account.freshfone_account.expire
        block_call
      rescue Exception => e
        Rails.logger.info "Error expiring spam account : Account ID::#{current_account.id} CallSid:: #{params[:CallSid]} : #{e.message}"  
      end
    end
end