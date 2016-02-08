module Freshfone::SupervisorActions
  include Freshfone::FreshfoneUtil
  include Freshfone::Endpoints
  include Freshfone::CallsRedisMethods

  def create_supervisor_leg
      current_call.supervisor_controls.create( :account_id => current_account.id,
          :supervisor_id => params[:agent],
          :supervisor_control_type => Freshfone::SupervisorControl::CALL_TYPE_HASH[:monitoring],
          :supervisor_control_status => Freshfone::SupervisorControl::CALL_STATUS_HASH[:default],
          :sid => params[:CallSid])
  end

  def complete_supervisor_leg
    if supervisor_leg?
      remove_device_from_outgoing client_id
      update_supervisor_leg
      empty_twiml
    end 
  end
private
  def supervisor_leg?
    params[:From].present? && get_call_id_from_redis(current_account.id,client_id,params[:CallSid]).present? 
  end

  def update_supervisor_leg
      current_call = freshfone_calls_scoper.find_by_id get_call_id_from_redis(current_account.id,client_id,params[:CallSid])
      supervisor_control = current_call.supervisor_controls.find_by_sid(params[:CallSid])
      supervisor_control.update_details({ :CallDuration => params[:CallDuration] , :status => Freshfone::SupervisorControl::CALL_STATUS_HASH[:success]})
  end

  def client_id 
    @client_id ||= split_client_id(params[:From])
  end
end
