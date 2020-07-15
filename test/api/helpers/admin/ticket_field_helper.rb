require File.join(Rails.root, 'test/api/helpers/admin/section_helper')
require File.join(Rails.root, 'test/api/helpers/admin/fsm_fields_helper')

module Admin::TicketFieldHelper
  include Admin::SectionHelper
  include Admin::FsmFieldsHelper

  DROPDOWN_CHOICES_TICKET_TYPE = %w[Question Problem Incident].freeze

  def launch_ticket_field_revamp
    @account.launch :ticket_field_revamp
    yield
  ensure
    @account.rollback :ticket_field_revamp
  end

  def enable_dynamic_sections_feature
    @account.add_feature :dynamic_sections
    yield
  ensure
    @account.revoke_feature :dynamic_sections
  end

  def enable_custom_ticket_fields_feature
    @account.add_feature :custom_ticket_fields
    yield
  ensure
    @account.revoke_feature :custom_ticket_fields
  end

  def stubs_hippa_and_custom_encrypted_field
    Account.current.stubs(:hipaa_enabled?).returns(true)
    Account.current.stubs(:custom_encrypted_fields_enabled?).returns(true)
    yield
    Account.current.unstub(:hipaa_enabled?)
    Account.current.unstub(:custom_encrypted_fields_enabled?)
  end

  def default_field_deletion_error_message?(tf)
    {
      'description' => 'Validation failed',
      'errors' => [
        {
          'field' => tf.name,
          'message' => "Default field '#{tf.name}' can't be deleted",
          'code' => 'invalid_value'
        }
      ]
    }
  end

  def custom_field_response(tf, options = {})
    response_hash = {
      id: tf.id,
      name: TicketDecorator.display_name(tf.name),
      label: tf.label,
      label_for_customers: tf.label_in_portal,
      position: tf.frontend_position,
      type: tf.field_type,
      default: tf.default,
      customers_can_edit: tf.editable_in_portal,
      required_for_closure: tf.required_for_closure,
      required_for_agents: tf.required,
      required_for_customers: tf.required_in_portal,
      displayed_to_customers: tf.visible_in_portal,
      created_at: tf.created_at.utc.iso8601,
      updated_at: options[:updated_at] || tf.updated_at.utc.iso8601,
      archived: tf.deleted
    }.merge(build_choices(tf))
                    .merge(section_mappings(tf))
                    .merge(dependent_fields(tf))
                    .merge(sections(tf))
    response_hash[:has_section] = true if tf.has_sections?
    response_hash
  end

  def build_choices(tf)
    drop_or_nested = proc { |type| ['custom_dropdown', 'nested_field', 'default_ticket_type'].include?(type) }
    case tf.field_type
    when drop_or_nested
      generate_dropdown_or_nested_choice(tf)
    when 'default_priority'
      { choices: TicketConstants.priority_names.collect do |priority|
        { label: priority[0], value: priority[1] }
      end }
    when 'default_source'
      { choices: TicketConstants.source_names.collect do |source|
        { label: source[0], value: source[1] }
      end }
    when 'default_status'
      status_choices = Account.current.ticket_status_values
      status_choices.map do |status|
        status_response_hash(status)
      end
    else
      {}
    end
  end

  def generate_dropdown_or_nested_choice(ticket_field)
    choices = []
    ticket_field.picklist_values.each do |level1|
      choice = hash_choice(level1, ticket_field.id)
      level1.sub_picklist_values.each do |level2|
        lvl2_choice = hash_choice(level2, level1.picklist_id)
        level2.sub_picklist_values.each do |level3|
          lvl2_choice[:choices] << hash_choice(level3, level2.picklist_id)
        end
        choice[:choices] << lvl2_choice
      end
      choices << choice
    end
    choices.present? ? { choices: choices } : {}
  end

  def hash_choice(picklist, parent_choice_id)
    {
      id: picklist.picklist_id,
      value: picklist.value,
      position: picklist.position,
      parent_choice_id: parent_choice_id,
      choices: []
    }
  end

  def status_response_hash(status)
    {
      id: status.status_id,
      label_for_customer: Helpdesk::TicketStatus.translate_status_name(status, 'customer_display_name'),
      value: Helpdesk::TicketStatus.translate_status_name(status, 'name'),
      stop_sla_timer: status.stop_sla_timer,
      default: status.is_default,
      deleted: status.deleted,
      group_ids: status.status_groups.map(&:group_id)
    }
  end

  def section_mappings(tf)
    sec_map = Account.current.section_fields.where(ticket_field_id: tf.id).map do |sf|
      {
        section_id: sf.section_id,
        position: sf.position
      }
    end
    sec_map.present? ? { section_mappings: sec_map } : {}
  end

  def sections(ticket_field)
    section = Account.current.sections.reload.where(ticket_field_id: ticket_field.id).map do |sec|
      res = {
        id: sec.id,
        label: sec.label,
        parent_ticket_field_id: ticket_field.id,
        choice_ids: Account.current.section_picklist_value_mappings.where(section_id: sec.id).pluck(:picklist_id),
        ticket_field_ids: Account.current.section_fields.where(section_id: sec.id).pluck(:ticket_field_id)
      }
      res.merge(fsm: sec.options[:fsm]) if sec.options[:fsm]
      res
    end
    section.present? ? { sections: section } : {}
  end

  def dependent_fields(tf)
    nested_levels = tf.child_levels.map do |child|
      {
        id: child.id,
        name: TicketDecorator.display_name(child.name),
        label: child.label,
        label_for_customers: child.label_in_portal,
        level: child.level,
        ticket_field_id: tf.id,
        created_at: child.created_at.utc.iso8601,
        updated_at: child.updated_at.utc.iso8601
      }
    end
    nested_levels.present? ? { dependent_fields: nested_levels } : {}
  end

  def create_ticket_fields_of_all_types
    name = 'checkbox' + Faker::Lorem.characters(rand(10..20))
    create_custom_field(name, :checkbox, rand(0..1) == 1)
    name = 'date' + Faker::Lorem.characters(rand(10..20))
    create_custom_field(name, :date, rand(0..1) == 1)
    name = "decimal_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field(name, :decimal, rand(0..1) == 1)
    name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field_dropdown(name, Faker::Lorem.words(6))
    name = 'number' + Faker::Lorem.characters(rand(10..20))
    create_custom_field(name, :number, field_num: '01', required: rand(0..1) == 1)
    name = "text_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field_dn(name, 'text', rand(0..1) == 1)
    name = "paragraph_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field_dn(name, 'paragraph', rand(0..1) == 1)
    names = Faker::Lorem.words(3).map { |x| "nested_#{x}" }
    create_dependent_custom_field(names, 2, rand(0..1) == 1)
    name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
    tf = create_custom_field_dropdown_with_sections(name, DROPDOWN_CHOICES_TICKET_TYPE)
    create_section_fields(tf.id)
  end

  def ticket_field_common_params(args = {})
    params_hash = {
      label: args[:label] || Faker::Lorem.characters(10),
      label_for_customers: args[:label_for_customers] || Faker::Lorem.characters(10),
      position: args[:position] || 1,
      type: args[:type] || 'custom_text'
    }
    params_hash.merge(args.except(*params_hash.keys))
  end

  def ticket_field_portal_params(args = {})
    params_hash = {
      required_for_closure: args[:required_for_closure] || false,
      required_for_agents: args[:required_for_agents] || false,
      required_for_customers: args[:required_for_customers] || false,
      customers_can_edit: args[:customers_can_edit] || false,
      displayed_to_customers: args[:displayed_to_customers] || false
    }
    params_hash.merge(args.except(*params_hash.keys))
  end

  def section_mapping_params(args = {})
    params_hash = {
      section_id: args[:section_id] || Faker::Number.number(2).to_i,
      position: args[:position] || Faker::Number.number(2).to_i
    }
    params_hash.merge(args.except(*params_hash.keys))
  end

  def json_response(response)
    ActiveSupport::JSON.decode(response.body).symbolize_keys
  end

  def wrap_cname(params)
    params
  end
end
