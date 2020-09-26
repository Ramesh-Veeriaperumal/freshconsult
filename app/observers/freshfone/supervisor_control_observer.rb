class Freshfone::SupervisorControlObserver < ActiveRecord::Observer
	observe Freshfone::SupervisorControl

	include Freshfone::NodeEvents

	def after_create(supervisor_control)
		account = supervisor_control.account
    publish_disable_supervisor_call(supervisor_control.call_id,
                  supervisor_control.supervisor_id, account) if publish_monitoring_control?(supervisor_control)
	end

	def after_update(supervisor_control)
		account = supervisor_control.account
		trigger_cost_job(supervisor_control)
    publish_enable_supervisor_call(supervisor_control.call_id,
                  supervisor_control.supervisor_id, account) if supervisor_control.monitoring?
	end
	
	private
		def add_cost_job(supervisor_control)
      		cost_params = { :account_id => supervisor_control.account_id,	:call => supervisor_control.call_id }
      		Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params) 
      		Rails.logger.debug "FreshfoneJob for sid : #{supervisor_control.sid} :: Supervisor Control Id :#{supervisor_control.id}"
    	end

	    def trigger_cost_job(supervisor_control)
	      return unless supervisor_control.supervisor_control_status_changed? && supervisor_control.cost.blank?
	      add_cost_job supervisor_control if supervisor_control.completed?
    	end

      def publish_monitoring_control?(supervisor_control)
        supervisor_control.monitoring? || supervisor_control.warm_transfer?
      end
end
