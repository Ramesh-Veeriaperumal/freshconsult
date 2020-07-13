module Admin::TicketFields::SectionMappingTestCases
  def test_success_create_with_section_mapping
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature do
        params = ticket_field_common_params
        type_field = Account.current.ticket_fields_only.find_by_field_type('default_ticket_type')
        picklist_ids = type_field.list_all_choices.pluck_all(:picklist_id)
        section1 = create_section(type_field, picklist_ids[0])
        section2 = create_section(type_field, picklist_ids[1])
        params[:section_mappings] = [section_mapping_params(section_id: section1.id, position: 1),
                                     section_mapping_params(section_id: section2.id, position: 1)]
        post :create, construct_params({}, params)
        assert_response 201
        ticket_field = @account.ticket_fields_with_nested_fields.find_by_field_type('custom_text')
        match_json(custom_field_response(ticket_field, updated_at: JSON.parse(response.body)['updated_at']))
      end
    end
  end

  def test_section_mapping_missing_position_for_multiple_data
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature do
        params = ticket_field_common_params
        type_field = Account.current.ticket_fields_only.find_by_field_type('default_ticket_type')
        picklist_ids = type_field.list_all_choices.pluck_all(:picklist_id)
        section1 = create_section(type_field, picklist_ids[0])
        section2 = create_section(type_field, picklist_ids[1])
        params[:section_mappings] = [section_mapping_params(section_id: section1.id),
                                     section_mapping_params(section_id: section2.id)]
        post :create, construct_params({}, params)
        assert_response 400
        expected_response = [section_position_bad_request_error(params[:label], section1.id, 1),
                             section_position_bad_request_error(params[:label], section2.id, 1)]
        match_json(expected_response)
      end
    end
  end

  def test_create_with_redundant_section_mapping
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature do
        section_id = create_section_fields.first
        params = ticket_field_common_params
        params[:section_mappings] = []
        2.times { params[:section_mappings] << section_mapping_params(section_id: section_id) }
        post :create, construct_params({}, params)
        assert_response 400
        assert_match("Duplicate values ('#{section_id}') present for ticket field", response.body)
      end
    end
  end

  def test_create_with_section_mapping_invalid_section_id
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature do
        section_id = Faker::Number.number(3).to_i
        params = ticket_field_common_params
        params[:section_mappings] = [section_mapping_params(section_id: section_id)]
        post :create, construct_params({}, params)
        assert_response 400
        assert_match("Section with id #{section_id} does not exist", response.body)
      end
    end
  end

  def test_create_with_section_mapping_missing_section_id
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature do
        params = ticket_field_common_params
        params[:section_mappings] = [{ position: 50 }]
        post :create, construct_params({}, params)
        assert_response 400
        assert_match('Mandatory parameters missing: (section_id)', response.body)
      end
    end
  end

  def test_section_mapping_position_out_of_range
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature do
        type_field = Account.current.ticket_fields_only.find_by_field_type('default_ticket_type')
        picklist_ids = type_field.list_all_choices.pluck_all(:picklist_id)
        section1 = create_section(type_field, picklist_ids[0])
        section2 = create_section(type_field, picklist_ids[1])
        params = ticket_field_common_params
        params[:section_mappings] = [section_mapping_params(section_id: section1.id, position: 0),
                                     section_mapping_params(section_id: section2.id, position: 2)]
        post :create, construct_params({}, params)
        assert_response 400
        expected_response = [section_position_bad_request_error(params[:label], section1.id, 1),
                             section_position_bad_request_error(params[:label], section2.id, 1)]
        match_json(expected_response)
      end
    end
  end

  def test_create_with_section_mapping_separate_parent_fields
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature do
        params = ticket_field_common_params
        params[:section_mappings] = []
        choices_one = [{ title: 'custom_field_section_1', value_mapping: ['Choice A'], ticket_fields: %w[test_custom_number test_custom_date] }]
        custom_field_one = create_custom_field_dropdown('test_custom_dropdown_1', choices_one.first[:value_mapping])
        parent_1_section_id = create_section_fields(custom_field_one.id, choices_one).first
        params[:section_mappings] << section_mapping_params(section_id: parent_1_section_id)
        choices_two = [{ title: 'custom_field_section_2', value_mapping: ['Choice 1'], ticket_fields: %w[test_custom_number test_custom_date] }]
        custom_field_two = create_custom_field_dropdown('test_custom_dropdown_2', choices_two.first[:value_mapping])
        parent_2_section_id = create_section_fields(custom_field_two.id, choices_two).first
        params[:section_mappings] << section_mapping_params(section_id: parent_2_section_id)
        post :create, construct_params({}, params)
        assert_response 400
        match_json([bad_request_error_pattern(:section_mappings, 
                                              'Ticket field can not reside inside sections belonging to two separate ticket fields',
                                              code: 'invalid_value')])
      end
    end
  end

  def test_create_section_mapping_without_feature
    launch_ticket_field_revamp do
      enable_dynamic_sections_feature {}
      type_field = Account.current.ticket_fields_only.find_by_field_type('default_ticket_type')
      picklist_ids = type_field.list_all_choices.pluck_all(:picklist_id)
      section1 = create_section(type_field, picklist_ids[0])
      section2 = create_section(type_field, picklist_ids[1])
      params = ticket_field_common_params
      params[:section_mappings] = [section_mapping_params(section_id: section1.id, position: 0)]
      post :create, construct_params({}, params)
      assert_response 403
      assert_match 'dynamic_sections feature', response.body
    end
  end

  def test_sanitization_of_section_name
    launch_ticket_field_revamp do
      type_field = Account.current.ticket_fields_only.find_by_field_type('default_ticket_type')
      picklist_ids = type_field.list_all_choices.pluck_all(:picklist_id)
      section_name = "<script>alert(‘#{Faker::Lorem.characters(rand(1..4))}’)</script>"
      section = create_section(type_field, picklist_ids[0], section_name)
      assert_equal section.label, RailsFullSanitizer.sanitize(section_name)
    end
  end
end
