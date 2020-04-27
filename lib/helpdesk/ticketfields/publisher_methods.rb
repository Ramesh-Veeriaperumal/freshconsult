module Helpdesk::Ticketfields::PublisherMethods

  include Helpdesk::Ticketfields::Choices

  def sections_hash
    association = has_sections? ? picklist_values : section_fields
    association.map(&:section).compact.uniq.map(&:central_publish_payload)
  end

  def construct_model_changes
    @model_changes ||= {}
    @model_changes.merge!(self.previous_changes.clone.to_hash)
    if @choices.present? && choice_fields?
      @status_changed = status_field?
      @type_changed = type_field?
    end
    @model_changes = {} if discardable_changes?
    @model_changes.symbolize_keys!
  end

  def model_changes=(options={})
    @model_changes ||= {}
    @model_changes.merge!(options)
  end

  def save_deleted_field_info
    @deleted_model_info = central_publish_payload
  end

  private

    def discardable_changes?
      return true if touched?
      @model_changes["position"].present? && @model_changes["position"].include?(nil) #@model_changes.keys.map(&:to_s).sort == ["position", "updated_at"]
    end

    def touched?
      @model_changes.keys == ["updated_at"]
    end

    def choice_fields?
      ['custom_dropdown', 'default_ticket_type', 'default_status', 'nested_field'].include?(field_type)
    end

end