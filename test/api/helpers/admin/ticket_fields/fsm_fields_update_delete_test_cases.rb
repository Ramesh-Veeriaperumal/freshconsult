module Admin::TicketFields::FsmFieldsUpdateDeleteTestCases
  def setup_fsm_fields
    clean_db
    type_field = Account.current.ticket_fields_only.find_by_field_type('default_ticket_type')
    picklist_ids = type_field.list_all_choices.pluck_all(:picklist_id)
    section = create_section(type_field, picklist_ids[0])
    section.label = 'Service task section'
    section.options = HashWithIndifferentAccess.new(fsm: true)
    section.options
    section.save!
    section
  end

  def set_up_fsm_ticket_field
    name = "cf_fsm__#{Faker::Lorem.characters(rand(10..20))}"
    tf = create_custom_field(name, :custom_text, rand(0..1) == 1)
    tf.field_options = { section: true, fsm: true }
    tf.save!
    tf
  end

  def test_fsm_fields_update
    launch_ticket_field_revamp do
      enable_multi_dynamic_sections_feature do
        add_fsm_feature do
          section = setup_fsm_fields
          params = fsm_field_update_params(section.id)
          expected_position = params[:section_mappings].find { |pos| pos[:position] }
          tf = set_up_fsm_ticket_field
          put :update, construct_params({ id: tf.id }, params)
          assert_response 200
          res = JSON.parse(response.body)
          updated_position = res['section_mappings'].find { |r| r.values_at('position') }
          assert_equal updated_position['position'], expected_position[:position]
        end
      end
    end
  end

  def test_delete_fsm_fields
    launch_ticket_field_revamp do
      tf = set_up_fsm_ticket_field
      delete :destroy, controller_params(id: tf.id)
      assert_response 204
    end
  end

  def test_delete_fsm_fields_with_fsm_feature
    launch_ticket_field_revamp do
      add_fsm_feature do
        tf = set_up_fsm_ticket_field
        delete :destroy, controller_params(id: tf.id)
        assert_response 400
        match_json(fsm_delete_validation_message)
      end
    end
  end

  def test_fsm_fields_update_with_invalid_field_options
    launch_ticket_field_revamp do
      add_fsm_feature do
        section = setup_fsm_fields
        tf = set_up_fsm_ticket_field
        params = fsm_field_invalid_update_params
        put :update, construct_params({ id: tf.id }, params)
        assert_response 400
        match_json(fsm_validation_message)
      end
    end
  end

  def test_fsm_fields_update_with_invalid_section_id
    launch_ticket_field_revamp do
      enable_multi_dynamic_sections_feature do
        add_fsm_feature do
          setup_fsm_fields
          tf = set_up_fsm_ticket_field
          params = fsm_field_invalid_update_section_params
          put :update, construct_params({ id: tf.id }, params)
          assert_response 400
          match_json(fsm_section_validation_message)
        end
      end
    end
  end
end
