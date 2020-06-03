class Helpdesk::Ticket < ActiveRecord::Base
  MARKETPLACE_PROPERTIES = [:requester_id, :responder_id, :group_id, :priority, :ticket_type, :source,
                            :status, :product_id, :owner_id, :isescalated, :fr_escalated, :spam, :deleted,
                            :long_tc01, :long_tc02, :internal_group_id, :internal_agent_id,
                            :association_type, :due_by, :fr_due_by, :nr_due_by, :sla_response_reminded,
                            :sla_resolution_reminded, :nr_reminded, :escalation_level, :fr_escalated, :nr_escalated].freeze

  def valid_marketplace_event?(action)
    (self.is_a?(Helpdesk::Ticket) && !archive && (action.eql?(:create) || marketplace_non_archive_destroy?(action) || valid_marketplace_changes?))
  end

  private

    def marketplace_non_archive_destroy?(action)
      action.eql?(:destroy) && !archive
    end

    def valid_marketplace_changes?
      (self.model_changes || {}).any? { |k, v| MARKETPLACE_PROPERTIES.include?(k) }
    end
end
