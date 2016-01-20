module Helpers::TicketFieldsTestHelper
  FIELD_MAPPING = { 'number' => 'int', 'checkbox' => 'boolean', 'paragraph' => 'text', 'decimal' => 'decimal', 'date' => 'date' }

  def create_custom_field(name, type)
    ticket_field_exists = @account.ticket_fields.find_by_name("#{name}_#{@account.id}")
    return ticket_field_exists if ticket_field_exists
    flexifield_mapping = type == 'text' ? 'ffs_13' : "ff_#{FIELD_MAPPING[type]}05"
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             flexifield_def_id: @account.flexi_field_defs.find_by_module('Ticket').id,
                                             flexifield_alias: "#{name.downcase}_#{@account.id}",
                                             flexifield_name: flexifield_mapping,
                                             flexifield_order: 5,
                                             flexifield_coltype: "#{type}",
                                             account_id: @account.id)
    flexifield_def_entry.save

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{name.downcase}_#{@account.id}",
                                                           label: name,
                                                           label_in_portal: name,
                                                           field_type: "custom_#{type}",
                                                           description: '',
                                                           flexifield_def_entry_id: flexifield_def_entry.id)
    parent_custom_field.save
    parent_custom_field
  end

  def create_custom_field_dropdown(name, choices)
    ticket_field_exists = @account.ticket_fields.find_by_name("#{name}_#{@account.id}")
    return ticket_field_exists if ticket_field_exists
    # ffs_04 is created here
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             flexifield_def_id: @account.flexi_field_defs.find_by_module('Ticket').id,
                                             flexifield_alias: "#{name.downcase}_#{@account.id}",
                                             flexifield_name: 'ffs_05',
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

  def create_dependent_custom_field(labels)
    flexifield_def_entry = []
    # ffs_07, ffs_08 and ffs_09 are created here
    ticket_field_exists = @account.ticket_fields.find_by_name("#{labels[0].downcase}_#{@account.id}")
    return ticket_field_exists if ticket_field_exists
    (0..2).each do |nested_field_id|
      flexifield_def_entry[nested_field_id] = FactoryGirl.build(:flexifield_def_entry,
                                                                flexifield_def_id: @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                                                flexifield_alias: "#{labels[nested_field_id].downcase}_#{@account.id}",
                                                                flexifield_name: "ffs_0#{nested_field_id + 7}",
                                                                flexifield_order: 6,
                                                                flexifield_coltype: 'dropdown',
                                                                account_id: @account.id)
      flexifield_def_entry[nested_field_id].save
    end

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{labels[0].downcase}_#{@account.id}",
                                                           label: labels[0],
                                                           label_in_portal: labels[0],
                                                           field_type: 'nested_field',
                                                           description: '',
                                                           flexifield_def_entry_id: flexifield_def_entry[0].id)
    parent_custom_field.save

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
                                                 [['New South Wales', '0', [['Sydney', '0']]],
                                                  ['Queensland', '0', [['Brisbane', '0']]]
                                                 ]
                                                ],
                                                ['USA', '0',
                                                 [['California', '0', [['Burlingame', '0'], ['Los Angeles', '0']]],
                                                  ['Texas', '0', [['Houston', '0'], ['Dallas', '0']]]
                                                 ]
                                                ]
                                               ],
                      'First' =>  [['001', '0',
                                    [['011', '0', [['111', '0']]],
                                     ['012', '0', [['121', '0']]]
                                    ]
                                   ],
                                   ['002', '0',
                                    [['021', '0', [['211', '0'], ['212', '0']]],
                                     ['022', '0', [['221', '0'], ['222', '0']]]
                                    ]
                                   ]
                                  ] }

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
    pattern.merge!(choices: hash[:choices] || Array) if hash[:choices] || tf.choices.present?
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
end
