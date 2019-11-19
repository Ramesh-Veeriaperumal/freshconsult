module Admin::TicketFieldHelper
  DROPDOWN_CHOICES_TICKET_TYPE = %w[Question Problem Incident].freeze

  def launch_ticket_field_revamp
    @account.launch :ticket_field_revamp
    yield
  rescue StandardError => e
    p e
  ensure
    @account.rollback :ticket_field_revamp
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

  def custom_field_response(tf)
    response_hash = {
      id: tf.id,
      name: TicketDecorator.display_name(tf.name),
      label: tf.label,
      label_for_customers: tf.label_in_portal,
      position: tf.position,
      type: tf.field_type,
      default: tf.default,
      customers_can_edit: tf.editable_in_portal,
      required_for_closure: tf.required_for_closure,
      required_for_agents: tf.required,
      required_for_customers: tf.required_in_portal,
      displayed_to_customers: tf.visible_in_portal,
      created_at: tf.created_at.utc.iso8601,
      updated_at: tf.updated_at.utc.iso8601
    }.merge(build_choices(tf))
      .merge(section_mappings(tf))
      .merge(dependent_fields(tf))
      .merge(sections(tf))
    response_hash.merge!(has_section: true) if tf.has_sections?
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
    choices.present? ? {choices: choices } : {}
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
    sec_map.present? ? { section_mappings: sec_map } :  {}
  end

  def sections(tf)
    sec = Account.current.sections.where(ticket_field_id: tf.id).map do |sec|
      {
          id: sec.id,
          label: sec.label,
          parent_ticket_field_id: tf.id,
          choice_ids: Account.current.section_picklist_value_mappings.where(section_id: sec.id).pluck(:picklist_id),
          ticket_field_ids: Account.current.section_fields.where(section_id: sec.id).pluck(:ticket_field_id)
      }
    end
    sec.present? ? { sections: sec } : {}
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
    nested_levels.present? ? { dependent_fields: nested_levels }: {}
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
end
