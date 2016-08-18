class Freshfone::Initiator::Supervisor
  
  include Freshfone::FreshfoneUtil
  include Freshfone::Endpoints
  include Freshfone::CallHistory
  include Freshfone::SupervisorActions

  attr_accessor :params, :current_account, :current_number, 
                :call_handler, :telephony
  
  def self.match?(params)
    params[:type] == "supervisor"
  end

  def initialize(params, current_account, current_number)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.telephony       = Freshfone::Telephony.new(params, current_account, current_number)
  end

  def process
    return reject_outgoing_call unless supervisable? && register_outgoing_device
    create_supervisor_leg
    telephony.join_conference({ :sid => select_conference_room,
      :beep => false,
      :startConferenceOnEnter => false,
      :endConferenceOnExit => false,
      :muted => true,
      :record => false })
  end

  private
  def supervisable?
    return unless current_account.features?(:freshfone_call_monitoring)
    current_user = current_account.users.find_by_id(client_id)
    current_call.inprogress? && 
    current_call.supervisor_controls.active.blank? && 
    !current_user.freshfone_user.busy_or_acw?
  end 

  def select_conference_room
    return current_call.agent_sid if warm_transfer_enabled? && current_call.meta.warm_transfer_meta?
    current_call.ancestry.present? ? current_call.dial_call_sid : current_call.call_sid
  end
end