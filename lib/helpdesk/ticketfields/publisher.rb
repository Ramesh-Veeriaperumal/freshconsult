module Helpdesk::Ticketfields::Publisher
  extend ActiveSupport::Concern
  
  module ClassMethods
    def ticket_field_publishable(options = {})
      Array(options.fetch(:on, [:create, :destroy])).each do |verb|
        safe_send("before_#{verb}") do
          backup_changes
        end
      end
      Array(options.fetch(:on, [:create, :destroy])).each do |verb|
        after_commit options.merge(on: verb) do
          publish_field
        end
      end
    end
  end

  def backup_changes
    @section_was = section.central_publish_payload
  end

  def _action
    [:create, :update, :destroy].find{ |action| transaction_include_action? action }
  end

  def publish_field
    if ticket_field
      ticket_field.model_changes = self.sections_changes
      ticket_field.updated_at = Time.now.utc
      ticket_field.save
    end
  end

  def section_field_changes?
    self.class.name == "Helpdesk::SectionField"
  end

  def section_changes?
    self.class.name == "Helpdesk::SectionPicklistValueMapping"
  end

  def section_was
    @section_was
  end

  def section_is
    payload = section.central_publish_payload
    if section_field_changes?
      if _action == :create
        payload[:section_fields] << ticket_field.id
      elsif _action == :destroy
        payload[:section_fields].delete(ticket_field.id)
      end
    end
    if section_changes?
      if _action == :create
        payload[:associated_picklist_values] << picklist_value.value
      elsif _action == :destroy
      payload[:associated_picklist_values].delete(picklist_value.value)
      end
    end
    payload
  end

  def sections_changes
    {
      :sections => [section_was, section_is]
    }
  end

end