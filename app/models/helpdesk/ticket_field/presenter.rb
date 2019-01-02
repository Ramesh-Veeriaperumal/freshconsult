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

  api_accessible :custom_translation do |tf|
    tf.add :label
    tf.add :label_in_portal, as: :customer_label
    tf.add proc { |field| field.fetch_custom_field_choices }, as: :choices, if: :field_with_choice?
  end

  def field_with_choice?
    ['nested_field', 'custom_dropdown', 'default_status', 'default_ticket_type'].include?(field_type)
  end

  # fetch the choices list for the given ticket field
  def fetch_custom_field_choices
    case field_type
    when 'custom_dropdown' then
      Hash[picklist_values.map { |ch| ["choice_#{ch.picklist_id}", ch.value] }]
    when 'nested_field' then
      Hash[fetch_nested_field_choices.map { |ch| ["choice_#{ch.picklist_id}", ch.value] }]
    when 'default_ticket_type' then
      Hash[Account.current.ticket_types_from_cache.map { |ch| ["choice_#{ch.picklist_id}", ch.value] }]
    when 'default_status' then
      Hash[Account.current.ticket_status_values_from_cache.select { |col| col.is_default == false }.map { |ch| ["choice_#{ch.status_id}", ch.name] }]
    else
      []
    end
  end

  # Fetch the choices for the given ticket field (including any level of nested field)
  # It actually works for any dropdown field which refers to picklist values table.
  def fetch_nested_field_choices
    nested_field_parent = []
    nested_field_child = []

    if parent
      nested_field_parent = parent.picklist_values
    else
      return picklist_values
    end

    nested_field_level = level - 1
    current_level = 0

    while current_level < nested_field_level
      nested_field_child = []
      nested_field_parent.each do |choice|
        nested_field_child.push(*choice.sub_picklist_values)
      end
      current_level += 1
      nested_field_parent = nested_field_child
    end

    nested_field_child
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
    # any conversion details
  end

  def relationship_with_account
    "ticket_fields_with_nested_fields"
  end

  def central_publish_worker_class
    "CentralPublishWorker::TicketFieldWorker"
  end
end
