class Helpdesk::TicketField < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |tf|
    tf.add :id
    tf.add :ticket_form_id, as: :form_id
    tf.add :name
    tf.add :label
    tf.add :label_in_portal
    tf.add :description
    tf.add :active
    tf.add :field_type
    tf.add :position
    tf.add :required
    tf.add :visible_in_portal
    tf.add :editable_in_portal
    tf.add :required_in_portal
    tf.add :required_for_closure
    tf.add :flexifield_def_entry_id, as: :def_entry_id
    tf.add :field_options
    tf.add :default
    tf.add :level
    tf.add :import_id
    tf.add :column_name
    tf.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    tf.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
    tf.add proc { |t| t.sections_hash }, as: :sections, if: proc { |t| t.has_sections? || t.section_field? } 
    tf.add proc { |t| t.section_field? }, as: :belongs_to_section
    tf.add proc { |t| t.nested_ticket_fields.map(&:central_publish_payload) }, as: :nested_ticket_fields, if: proc { |t| t.nested_field? }
    tf.add proc { |t| t.ticket_field_choices_payload }, as: :choices
    # tf.add :associations
  end

  def central_payload_type
    action = [:create, :update, :destroy].find{ |action| 
      transaction_include_action? action }
    "ticket_field_#{action}"
  end

  def self.central_publish_enabled?
    Account.current.ticket_fields_central_publish_enabled?
  end

  def model_changes_for_central
    @model_changes
  end

  def misc_changes_for_central
    #any conversion details
  end

  def relationship_with_account
    "ticket_fields_with_nested_fields"
  end

  def central_publish_worker_class
    "CentralPublishWorker::TicketFieldWorker"
  end

end
