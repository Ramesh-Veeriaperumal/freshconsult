require_relative '../test_helper'

class ApiTicketFieldsControllerTest < ActionController::TestCase
  include Helpers::TicketFieldsTestHelper
  def wrap_cname(_params)
    remove_wrap_params
    {}
  end

  def test_index_ignores_pagination
    get :index, controller_params(per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count > 1
  end

  def test_index_with_choices
    pdt = Product.new(name: 'New Product')
    pdt.account_id = @account.id
    pdt.save
    get :index, controller_params({}, {})
    assert_response 200
    pattern = []
    @account.ticket_fields.each do |field|
      case field.field_type
      when 'default_requester'
        new_pattern = requester_ticket_field_pattern(field)
      when 'nested_field'
        new_pattern = ticket_field_nested_pattern(field, choices: field.formatted_nested_choices)
      else
        new_pattern = ticket_field_pattern(field)
        klass = TicketFieldDecorator.new(field, {}).ticket_field_choices.class
        new_pattern.merge!(choices: Hash) if klass == Hash
      end
      pattern << new_pattern
    end
    match_json pattern.ordered!
  end

  def test_index_with_custom_dropdown
    labels = ['test_custom_dropdown']
    # ffs_04 is created here
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             flexifield_def_id: @account.flexi_field_defs.find_by_module('Ticket').id,
                                             flexifield_alias: "#{labels[0].downcase}_#{@account.id}",
                                             flexifield_name: 'ffs_04',
                                             flexifield_order: 5,
                                             flexifield_coltype: 'dropdown',
                                             account_id: @account.id)
    flexifield_def_entry.save

    parent_custom_field = FactoryGirl.build(:ticket_field, account_id: @account.id,
                                                           name: "#{labels[0].downcase}_#{@account.id}",
                                                           label: labels[0],
                                                           label_in_portal: labels[0],
                                                           field_type: 'custom_dropdown',
                                                           description: '',
                                                           flexifield_def_entry_id: flexifield_def_entry.id)
    parent_custom_field.save

    field_choices = [['Get Smart', '0'],
                     ['Pursuit of Happiness', '0'],
                     ['Armaggedon', '0']
                    ]
    pv_attr = [{ 'value' => 'Get Smart' },
               { 'value' => 'Pursuit of Happiness' },
               { 'value' => 'Armaggedon' }
              ]

    picklist_vals_l1 = []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                             pickable_type: 'Helpdesk::TicketField',
                                                             pickable_id: parent_custom_field.id,
                                                             position: index1 + 1,
                                                             value: l1_val)
      picklist_vals_l1.last.save
    end
    get :index, controller_params({}, {})
    assert_response 200
    response = parse_response @response.body
    assert_equal 12, response.count
    cd_field = response.find { |x| x['type'] == 'custom_dropdown' }
    assert_equal ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'], cd_field['choices']
  end

  def test_index_nested_choices_three_level
    flexifield_def_entry = []
    labels = %w(test_custom_country test_custom_state test_custom_city)
    # ffs_07, ffs_08 and ffs_09 are created here
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

    field_choices = [['Australia', '0',
                      [['New South Wales', '0', [['Sydney', '0']]],
                       ['Queensland', '0', [['Brisbane', '0']]]
                      ]
                     ],
                     ['USA', '0',
                      [['California', '0', [['Burlingame', '0'], ['Los Angeles', '0']]],
                       ['Texas', '0', [['Houston', '0'], ['Dallas', '0']]]
                      ]
                     ]
                    ]
    field_choices_del = [['Australia', '0',
                          [['New South Wales', '0'], ['Queensland', '0']]
                         ],
                         ['USA', '0',
                          [['California', '0'], ['Texas', '0']]
                         ]
                        ]

    picklist_vals_l1 = []
    picklist_vals_l2 = []
    picklist_vals_l3 = []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                             pickable_type: 'Helpdesk::TicketField',
                                                             pickable_id: parent_custom_field.id,
                                                             position: index1 + 1,
                                                             value: l1_val)
      picklist_vals_l1.last.save

      field_choices[index1][2].map(&:first).each_with_index do |l2_val, index2|
        picklist_vals_l2 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                               pickable_type: 'Helpdesk::PicklistValue',
                                                               pickable_id: picklist_vals_l1[picklist_vals_l1.length - 1].id,
                                                               position: index2 + 1,
                                                               value: l2_val)
        picklist_vals_l2.last.save
        field_choices[index1][2][index2][2].map(&:first).each_with_index do |l3, index3|
          picklist_vals_l3 << FactoryGirl.build(:picklist_value, account_id: @account.id,
                                                                 pickable_type: 'Helpdesk::PicklistValue',
                                                                 pickable_id: picklist_vals_l2[picklist_vals_l2.length - 1].id,
                                                                 position: index3 + 1,
                                                                 value: l3)
          picklist_vals_l3.last.save
        end
      end
    end
    get :index, controller_params({}, {})
    assert_response 200
    response = parse_response @response.body
    assert_equal @account.main_portal.ticket_fields.count, response.count
    field = @account.ticket_fields.where(field_type: 'nested_field').first
    relevant_response = response.find { |x| x['id'] == field.id }
    match_custom_json(relevant_response.to_json, ticket_field_nested_pattern(field, choices: {
                                                                               'Australia' => { 'New South Wales' => ['Sydney'],  'Queensland' => ['Brisbane'] },
                                                                               'USA' => { 'California' => ['Burlingame', 'Los Angeles'],
                                                                                          'Texas' => ['Houston', 'Dallas'] } }))
    field.nested_ticket_fields.each do |x|
      relevant_ntf = relevant_response['nested_ticket_fields'].find { |ntf| ntf['id'] == x.id }
      match_custom_json(relevant_ntf.to_json, nested_ticket_fields_pattern(x))
    end
  end

  def test_index_with_invalid_filter
    get :index, controller_params({ test: 'junk' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('test', :invalid_field)])
  end

  def test_index_with_invalid_filter_value
    get :index, controller_params({ type: 'junk' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('type', :"can't be blank")])
  end

  def test_index_with_valid_filter
    get :index, controller_params({ type: 'nested_field' }, {})
    assert_response 200
    response = parse_response @response.body
    assert_equal ['nested_field'], response.map { |x| x['type'] }.uniq
    assert_equal 1, response.count
  end
end
