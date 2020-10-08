class Helpdesk::Ticket < ActiveRecord::Base
  APP_PROPERTIES = [:requester_id, :responder_id, :group_id, :priority, :ticket_type, :source,
                            :status, :product_id, :owner_id, :isescalated, :fr_escalated, :spam, :deleted,
                            :long_tc01, :long_tc02, :internal_group_id, :internal_agent_id,
                            :association_type, :due_by, :fr_due_by, :nr_due_by, :sla_response_reminded,
                            :sla_resolution_reminded, :nr_reminded, :escalation_level, :fr_escalated, :nr_escalated].freeze

  def valid_app_event?(action)
    self.is_a?(Helpdesk::Ticket) && !@manual_central_publish && !archive && (action.eql?(:create) || action.eql?(:destroy) || valid_app_changes?)
  end

  private

    def valid_app_changes?
      (self.model_changes || {}).any? { |k, v| APP_PROPERTIES.include?(k) }
    end
end
