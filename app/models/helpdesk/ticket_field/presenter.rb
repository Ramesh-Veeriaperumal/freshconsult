class Helpdesk::TicketField < ActiveRecord::Base
  include RepresentationHelper

  TRANSLATION_CHOICE_FIELDS = ['nested_field', 'custom_dropdown', 'default_status', 'default_ticket_type'].freeze
  LABEL_AND_CHOICES_TRANSLATION_AVAILABLE_DEFAULT_FIELDS = ['default_status', 'default_ticket_type'].freeze

  acts_as_api

  api_accessible :base do |tf|
    tf.add :id
    tf.add :label
    tf.add :description
    tf.add :position
    tf.add :default
    tf.add :required_for_closure
    tf.add proc { |object| object.utc_format(object.created_at) }, as: :created_at
    tf.add proc { |object| object.utc_format(object.updated_at) }, as: :updated_at
  end

  api_accessible :common_field_api, extend: :base do |tf|
    tf.add proc { |obj| TicketDecorator.display_name(obj.name) }, as: :name
    tf.add :label_in_portal, as: :label_for_customers
    tf.add :field_type, as: :type
    tf.add :required, as: :required_for_agents
    tf.add :required_in_portal, as: :required_for_customers
    tf.add :visible_in_portal, as: :displayed_to_customers
    tf.add :editable_in_portal, as: :customers_can_edit
  end

  api_accessible :nested_field_api, extend: :common_field_api do |tf|
    tf.add :nested_ticket_fields, template: :api
    tf.add proc { |object| object.nested_dropdown_choices_with_display_id }, as: :choices
  end

  api_accessible :custom_dropdown_field_api, extend: :common_field_api do |tf|
    tf.add proc { |object| object.custom_dropdown_choices_with_display_id }, as: :choices
  end

  api_accessible :central_publish, extend: :base do |tf|
    tf.add :account_id
    tf.add :name
    tf.add :ticket_form_id, as: :form_id
    tf.add :label_in_portal
    tf.add :active
    tf.add :field_type
    tf.add :required
    tf.add :visible_in_portal
    tf.add :editable_in_portal
    tf.add :required_in_portal
    tf.add :flexifield_def_entry_id, as: :def_entry_id
    tf.add :field_options
    tf.add :level
    tf.add :import_id
    tf.add :column_name
    tf.add :deleted
    tf.add proc { |object| object.section_field? }, as: :belongs_to_section
    tf.add proc { |t| t.sections_hash }, as: :sections, if: proc { |t| t.has_sections? || t.section_field? }
    tf.add proc { |object| object.nested_ticket_fields.map(&:central_publish_payload) }, as: :nested_ticket_fields, if: proc { |obj| obj.nested_field? }
    tf.add proc { |t| t.ticket_field_choices_payload }, as: :choices
    # tf.add :associations
  end

  api_accessible :custom_translation do |tf|
    tf.add :label, unless: :only_customer_label_field?
    tf.add :label_in_portal, as: :customer_label, unless: :only_agent_label_field?
    tf.add proc { |field| field.fetch_custom_field_choices }, as: :choices, if: :field_with_choice?
  end

  api_accessible :custom_translation_secondary do |t|
    t.add ->(model, options) { model.fetch_label(options[:lang]) }, as: :label, unless: :only_customer_label_field?
    t.add ->(model, options) { model.fetch_customer_label(options[:lang]) }, as: :customer_label, unless: :only_agent_label_field?
    t.add ->(model, options) { model.fetch_choices(options[:lang]) }, as: :choices, if: :field_with_choice?
  end

  def fetch_label(lang)
    tf = parent_id.nil? ? self : parent
    translation = tf.safe_send("#{lang}_translation").try(:translations)
    return '' if translation.nil?
    unless parent_id.nil?
      return translation["label_#{level}"] ? translation["label_#{level}"] : ''
    end
    
    translation['label'] || ''
  end

  def fetch_customer_label(lang)
    tf = parent_id.nil? ? self : parent
    translation = tf.safe_send("#{lang}_translation").try(:translations)
    return '' if translation.nil?
    unless parent_id.nil?
      return translation["customer_label_#{level}"] ? translation["customer_label_#{level}"] : ''
    end

    translation['customer_label'] || ''
  end

  def fetch_choices(lang)
    tf = parent_id.nil? ? self : parent
    translation = tf.safe_send("#{lang}_translation").try(:translations)
    Hash[fetch_custom_field_choices.map { |key, value| [key, translation && translation['choices'][key].present? ? translation['choices'][key] : ''] }]
  end

  def field_with_choice?
    translation_choice_fields.include?(field_type)
  end

  def only_customer_label_field?
    default && label_and_choices_translation_available_default_fields.exclude?(field_type)
  end

  def only_agent_label_field?
    default && label_translations_available_only_for_agents.include?(field_type)
  end

  def source_translations_allowed?
    Account.current.ticket_source_revamp_enabled?
  end

  def label_and_choices_translation_available_default_fields
    source_translations_allowed? ? ['default_status', 'default_ticket_type', 'default_source'] : LABEL_AND_CHOICES_TRANSLATION_AVAILABLE_DEFAULT_FIELDS
  end

  def translation_choice_fields
    source_translations_allowed? ? ['nested_field', 'custom_dropdown', 'default_status', 'default_ticket_type', 'default_source'] : TRANSLATION_CHOICE_FIELDS
  end

  def label_translations_available_only_for_agents
    ['default_source']
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
    when 'default_source' then
      source_translations_allowed? ? Hash[Account.current.ticket_source_from_cache.select { |col| col.default == false }.map { |ch| ["choice_#{ch.account_choice_id}", ch.name] }] : []
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

  # nested_choices with picklist_ids
  def nested_dropdown_choices_with_display_id
    nested_choices_with_display_id(picklist_values)
  end

  def nested_choices_with_display_id(picklist_values)
    picklist_values.collect do |picklist_value|
      {
        id: picklist_value.picklist_id,
        value: picklist_value.value,
        position: picklist_value.position,
        choices: nested_choices_with_display_id(picklist_value.sub_picklist_values)
      }
    end
  end

  # custom_dropdown choices with_picklist_ids
  def custom_dropdown_choices_with_display_id
    picklist_values.collect { |picklist_value| picklist_hash(picklist_value) }
  end

  def picklist_hash(picklist_value)
    {
      value: picklist_value.value,
      id: picklist_value.picklist_id,
      position: picklist_value.position
    }
  end

  def central_payload_type
    action = [:create, :update, :destroy].find{ |action| 
      transaction_include_action? action }
    "ticket_field_#{action}"
  end

  def model_changes_for_central
    @model_changes
  end

  def misc_changes_for_central
    # any conversion details
  end

  def relationship_with_account
    'all_ticket_fields_with_nested_fields'
  end

  def central_publish_worker_class
    "CentralPublishWorker::TicketFieldWorker"
  end

end