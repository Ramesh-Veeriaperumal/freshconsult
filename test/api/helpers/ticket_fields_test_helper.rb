module TicketFieldsTestHelper
  include Helpdesk::Ticketfields::ControllerMethods

  FIELD_MAPPING = { 'number' => 'int', 'checkbox' => 'boolean', 'paragraph' => 'text', 'decimal' => 'decimal', 'date' => 'date' }.freeze
  SECTIONS_FOR_TYPE = [ { title: 'section1', value_mapping: %w(Question Problem), ticket_fields: %w(test_custom_number test_custom_date) },
                        { title: 'section2', value_mapping: ['Incident'], ticket_fields: %w(test_custom_paragraph test_custom_dropdown) } ]
  SECTIONS_FOR_CUSTOM_DROPDOWN = [ { title: 'section1', value_mapping: %w(Choice\ 1 Choice\ 2), ticket_fields: %w(test_custom_number test_custom_date) },
                                   { title: 'section2', value_mapping: ['Choice 3'], ticket_fields: %w(test_custom_paragraph) } ]


  def create_custom_field(name, type, required = false, required_for_closure = false)
    ticket_field_exists = @account.ticket_fields.find_by_name("#{name}_#{@account.id}")
    if ticket_field_exists
      ticket_field_exists.update_attributes(required: required, required_for_closure: required_for_closure)
      return ticket_field_exists
    end
    flexifield_mapping = type == 'text' ? unused_ffs_col : "ff_#{FIELD_MAPPING[type]}05"
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             flexifield_def_id: @account.flexi_field_defs.find_by_module('Ticket').id,
                                             flexifield_alias: "#{name.downcase}_#{@account.id}",
                                             flexifield_name: flexifield_mapping,
                                             flexifield_order: 5,
                                             flexifield_coltype: type.to_s,
                                             account_id: @account.id)
    flexifield_def_entry.save

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{name.downcase}_#{@account.id}",
                                                           label: name,
                                                           label_in_portal: name,
                                                           field_type: "custom_#{type}",
                                                           description: '',
                                                           required: required,
                                                           required_for_closure: required_for_closure,
                                                           column_name: flexifield_def_entry.flexifield_name,
                                                           flexifield_def_entry_id: flexifield_def_entry.id)
    parent_custom_field.save
    parent_custom_field
  end

  def create_custom_status(name = 'custom status', stop_sla_timer = true)
    status_field = @account.ticket_fields.find_by_name('status')
    last_status = Helpdesk::TicketStatus.last
    status_values = FactoryGirl.build(:ticket_status,  account_id: @account.id,
                                                       name: name,
                                                       customer_display_name: name,
                                                       stop_sla_timer: stop_sla_timer,
                                                       position: last_status.position + 1,
                                                       status_id: last_status.status_id + 1,
                                                       ticket_field_id: status_field.id)
    status_values.save
    status_values
  end

  def create_section_fields(parent_ticket_field_id = 3, sections = SECTIONS_FOR_TYPE, required = false, required_for_closure = false)
    sections.each do |section|
      sections_fields = section[:ticket_fields].each_with_object([]) do |field, array|
        pos = 0
        ticket_field = case field
        when 'dropdown'
          create_custom_field_dropdown('test_custom_dropdown', Faker::Lorem.words(5), required, required_for_closure)
        when 'dependent'
          create_dependent_custom_field(['test_custom_dependent_one',  'test_custom_dependent_two', 'test_custom_dependent_three'], 2)
        else
          create_custom_field(field, field, required, required_for_closure)
        end
        ticket_field.update_attributes(field_options: { section: true })
        array << { ticket_field_id: ticket_field.id, parent_ticket_field_id: parent_ticket_field_id, position: (pos + 1) }
      end
      section_object = FactoryGirl.build(:section, label: section[:title],
                                                   account_id: @account.id)
      section_object.save
      section_picklist_mappings = []
      section[:value_mapping].each do |value|
        section_picklist_mappings << FactoryGirl.build(:section_picklist_mapping,  account_id: @account.id,
                                                                                   section_id: section_object.id,
                                                                                   picklist_value_id: Helpdesk::PicklistValue.find_by_value(value).id)
        section_picklist_mappings.last.save
      end

      section_fields_record = []
      sections_fields.each do |field|
        section_fields_record << FactoryGirl.build(:section_field,  account_id: @account.id,
                                                                    section_id: section_object.id,
                                                                    ticket_field_id: field[:ticket_field_id],
                                                                    parent_ticket_field_id: field[:parent_ticket_field_id],
                                                                    position: field[:position])
        section_fields_record.last.save
      end
    end
  end

  def create_custom_field_dropdown(name = 'test_custom_dropdown', choices = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'], field_name = "05", required = false, required_for_closure = false)
    ticket_field_exists = @account.ticket_fields.find_by_name("#{name}_#{@account.id}")
    if ticket_field_exists
      ticket_field_exists.update_attributes(required: required, required_for_closure: required_for_closure)
      return ticket_field_exists
    end
    # ffs_04 is created here
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             flexifield_def_id: @account.flexi_field_defs.find_by_module('Ticket').id,
                                             flexifield_alias: "#{name.downcase}_#{@account.id}",
                                             flexifield_name: "ffs_#{field_name}",
                                             flexifield_order: 5,
                                             flexifield_coltype: 'dropdown',
                                             account_id: @account.id)
    flexifield_def_entry.save

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{name.downcase}_#{@account.id}",
                                                           label: name,
                                                           label_in_portal: name,
                                                           field_type: 'custom_dropdown',
                                                           description: '',
                                                           required: required,
                                                           required_for_closure: required_for_closure,
                                                           column_name: "ffs_#{field_name}",
                                                           flexifield_def_entry_id: flexifield_def_entry.id)
    parent_custom_field.save

    field_choices = choices.map { |x| [x, '0'] }
    pv_attr = choices.map { |x| { 'value' => x } }

    picklist_vals_l1 = []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                             pickable_type: 'Helpdesk::TicketField',
                                                             pickable_id: parent_custom_field.id,
                                                             position: index1 + 1,
                                                             value: l1_val)
      picklist_vals_l1.last.save
    end
    parent_custom_field
  end

  def create_custom_field_dropdown_with_sections(name = 'section_custom_dropdown', choices = ['Choice 1', 'Choice 2', 'Choice 3'], required = false)
    ticket_field_exists = @account.ticket_fields.find_by_name("#{name}_#{@account.id}")
    return ticket_field_exists if ticket_field_exists
    # ffs_06 is created here
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             flexifield_def_id: @account.flexi_field_defs.find_by_module('Ticket').id,
                                             flexifield_alias: "#{name.downcase}_#{@account.id}",
                                             flexifield_name: 'ffs_06',
                                             flexifield_order: 7,
                                             flexifield_coltype: 'dropdown',
                                             account_id: @account.id)
    flexifield_def_entry.save

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{name.downcase}_#{@account.id}",
                                                           label: name,
                                                           label_in_portal: name,
                                                           field_type: 'custom_dropdown',
                                                           description: '',
                                                           required: required,
                                                           field_options: {'section_present' => true},
                                                           flexifield_def_entry_id: flexifield_def_entry.id)
    parent_custom_field.save

    field_choices = choices.map { |x| [x, '0'] }
    pv_attr = choices.map { |x| { 'value' => x } }

    picklist_vals_l1 = []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                             pickable_type: 'Helpdesk::TicketField',
                                                             pickable_id: parent_custom_field.id,
                                                             position: index1 + 1,
                                                             value: l1_val)
      picklist_vals_l1.last.save
    end
    parent_custom_field
  end

  def create_dependent_custom_field(labels, id = nil)
    flexifield_def_entry = []
    # ffs_07, ffs_08 and ffs_09 are created here
    ticket_field_exists = @account.ticket_fields.find_by_name("#{labels[0].downcase}_#{@account.id}")
    return ticket_field_exists if ticket_field_exists

    flexifield_def_entry[0] = FactoryGirl.build(:flexifield_def_entry,
                                                flexifield_def_id: @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                                flexifield_alias: "#{labels[0].downcase}_#{@account.id}",
                                                flexifield_name: "ffs_0#{id || 7}",
                                                flexifield_order: 6,
                                                flexifield_coltype: 'dropdown',
                                                account_id: @account.id)
    flexifield_def_entry[0].save

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{labels[0].downcase}_#{@account.id}",
                                                           label: labels[0],
                                                           label_in_portal: labels[0],
                                                           field_type: 'nested_field',
                                                           description: '',
                                                           flexifield_def_entry_id: flexifield_def_entry[0].id)
    parent_custom_field.save

    (1..2).each do |nested_field_id|
      flexifield_def_entry[nested_field_id] = FactoryGirl.build(:flexifield_def_entry,
                                                                flexifield_def_id: @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                                                flexifield_alias: "#{labels[nested_field_id].downcase}_#{@account.id}",
                                                                flexifield_name: "ffs_0#{nested_field_id + (id || 7)}",
                                                                flexifield_order: 6,
                                                                flexifield_coltype: 'dropdown',
                                                                account_id: @account.id)

      nested_field_params = { name: "#{labels[nested_field_id].downcase}_#{@account.id}", label_in_portal: labels[nested_field_id], label: labels[nested_field_id], level: nested_field_id + 1 }
      is_saved = create_nested_field(flexifield_def_entry[nested_field_id], parent_custom_field, nested_field_params.merge(type: 'nested_field'), @account)
      construct_child_levels(flexifield_def_entry[nested_field_id], parent_custom_field, nested_field_params) if is_saved

      flexifield_def_entry[nested_field_id].save
    end

    nested_field_vals = []
    (1..2).each do |nf|
      nested_field_vals[nf - 1] = FactoryGirl.build(:nested_ticket_field, account_id: @account.id,
                                                                          name: "#{labels[nf].downcase}_#{@account.id}",
                                                                          flexifield_def_entry_id: flexifield_def_entry[nf].id,
                                                                          label: labels[nf],
                                                                          label_in_portal: labels[nf],
                                                                          ticket_field_id: parent_custom_field.id,
                                                                          level: nf + 1)
      nested_field_vals[nf - 1].save
    end

    field_choices = { 'test_custom_country' => [['Australia', '0',
                                                 [['New South Wales', '0', [%w[Sydney 0]]],
                                                  ['Queensland', '0', [%w[Brisbane 0]]]]],
                                                ['USA', '0',
                                                 [['California', '0', [%w[Burlingame 0], ['Los Angeles', '0']]],
                                                  ['Texas', '0', [%w[Houston 0], %w[Dallas 0]]]]]],
                      'test_custom_dependent_one' => [['Australia', '0',
                                                   [['New South Wales', '0', [%w[Sydney 0]]],
                                                    ['Queensland', '0', [%w[Brisbane 0]]]]],
                                                  ['USA', '0',
                                                   [['California', '0', [%w[Burlingame 0], ['Los Angeles', '0']]],
                                                    ['Texas', '0', [%w[Houston 0], %w[Dallas 0]]]]]],
                      'First' => [['001', '0',
                                   [['011', '0', [%w[111 0]]],
                                    ['012', '0', [%w[121 0]]]]],
                                  ['002', '0',
                                   [['021', '0', [%w[211 0], %w[212 0]]],
                                    ['022', '0', [%w[221 0], %w[222 0]]]]]] }

    picklist_vals_l1 = []
    picklist_vals_l2 = []
    picklist_vals_l3 = []
    field_choices[labels[0]].map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                             pickable_type: 'Helpdesk::TicketField',
                                                             pickable_id: parent_custom_field.id,
                                                             position: index1 + 1,
                                                             value: l1_val)
      picklist_vals_l1.last.save

      field_choices[labels[0]][index1][2].map(&:first).each_with_index do |l2_val, index2|
        picklist_vals_l2 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                               pickable_type: 'Helpdesk::PicklistValue',
                                                               pickable_id: picklist_vals_l1[picklist_vals_l1.length - 1].id,
                                                               position: index2 + 1,
                                                               value: l2_val)
        picklist_vals_l2.last.save
        field_choices[labels[0]][index1][2][index2][2].map(&:first).each_with_index do |l3, index3|
          picklist_vals_l3 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                                 pickable_type: 'Helpdesk::PicklistValue',
                                                                 pickable_id: picklist_vals_l2[picklist_vals_l2.length - 1].id,
                                                                 position: index3 + 1,
                                                                 value: l3)
          picklist_vals_l3.last.save
        end
      end
    end
    parent_custom_field
  end

  def ticket_field_pattern(tf, hash = {})
    pattern = {
      id: tf.id,
      default: tf.default.to_s.to_bool,
      description: tf.description,
      type: tf.field_type,
      customers_can_edit: tf.editable_in_portal.to_s.to_bool,
      label: tf.label,
      label_for_customers: tf.label_in_portal,
      name: tf.default ? tf.name : tf.name[0..-3],
      position: tf.position,
      required_for_agents: tf.required.to_s.to_bool,
      required_for_closure: tf.required_for_closure.to_s.to_bool,
      required_for_customers: tf.required_in_portal.to_s.to_bool,
      displayed_to_customers: tf.visible_in_portal.to_s.to_bool,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    pattern[:choices] = hash[:choices] || Array if hash[:choices] || tf.choices.present?
    pattern
  end

  def requester_ticket_field_pattern(tf)
    ticket_field_pattern(tf).merge(
      portal_cc: tf.field_options['portalcc'],
      portal_cc_to: tf.field_options['portalcc_to']
    )
  end

  def ticket_field_nested_pattern(tf, hash = {})
    nested_ticket_field_pattern = []
    tf.nested_ticket_fields.each do |x|
      nested_ticket_field_pattern << nested_ticket_fields_pattern(x)
    end
    ticket_field_pattern(tf, hash).merge(
      nested_ticket_fields: nested_ticket_field_pattern
    )
  end

  def nested_ticket_fields_pattern(ntf)
    {
      description: ntf.description,
      id: ntf.id,
      label: ntf.label,
      label_in_portal: ntf.label_in_portal,
      level: ntf.level,
      name: ntf.name[0..-3],
      ticket_field_id: ntf.ticket_field_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def section_field_pattern(tf)
    pattern = ticket_field_pattern(tf)
    sections = tf.dynamic_section_fields.includes(:section).map(&:section).uniq
    section_pattern = sections.each_with_object([]) do |field, array_list|
      array_list << { title: field.label, choices: field.section_picklist_mappings.map { |x| x.picklist_value.value }, participating_fields: field.section_fields.includes(:ticket_field).map { |x| x.ticket_field.name[0..-3] } }
    end
    pattern[:sections] = section_pattern
    pattern
  end

  # ticket export csv field_options
  def ticket_export_fields
    flexi_fields = Account.current.ticket_fields_from_cache.select { |x| x.default == false }.map(&:name).collect { |x| display_name(x, :ticket) }
    default_fields = Helpdesk::TicketModelExtension.allowed_ticket_export_fields
    default_fields += ['product_name'] if Account.current.multi_product_enabled?
    default_fields + flexi_fields + ['description']
  end

  def display_name(name, type = nil)
    return name[0..(-Account.current.id.to_s.length - 2)] if type == :ticket
    name[3..-1]
  end

  def create_skill
    skills = []
    2.times do
      skills << Account.current.skills.new(
        :name => Faker::Lorem.words(3).join(' '),
        :match_type => "all"
      )
    end
    skills
  end

  private
    def unused_ffs_col
      ffs_col = ''
      loop do
        ffs_col = "ffs_#{Random.rand(13..20)}"
        break unless ffs_col_taken? ffs_col
      end
      return ffs_col 
    end

    def ffs_col_taken?(ffs_col)
      @account.flexifield_def_entries.select{|flexifield| flexifield['flexifield_name'] == ffs_col}.present?
    end
end
