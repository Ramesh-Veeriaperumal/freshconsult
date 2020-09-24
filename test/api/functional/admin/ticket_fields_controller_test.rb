require_relative '../../test_helper.rb'
require Rails.root.join('test/api/helpers/ticket_fields_test_helper')
require Rails.root.join('test/api/helpers/admin/ticket_field_helper')
require Rails.root.join('test/api/helpers/admin/associated_model_test_cases')
require Rails.root.join('test/api/helpers/test_case_methods')

require 'faker'

class Admin::TicketFieldsControllerTest < ActionController::TestCase
  include TestCaseMethods
  include TicketFieldsTestHelper
  include Admin::TicketFieldHelper
  include Admin::AssociatedModelTestCases

  PICKLIST_TYPE_FIELDS = [:nested_field, :dropdown].freeze
  DENORMALIZED_FIELDS = [:text, :paragraph, :encrypted_text].freeze

  def setup
    super
    clean_db
    Account.current.add_feature(:custom_ticket_fields)
  end

  def teardown
    Account.current.revoke_feature(:custom_ticket_fields)
    clean_db
    super
  end

  def clean_db
    @account.ticket_fields_with_archived_fields.where(default: 0).destroy_all
    @account.helpdesk_sources.custom.destroy_all
    type_field = @account.ticket_fields.find_by_field_type('default_ticket_type')
    type_field.sections.destroy_all
    type_field.field_options = type_field.field_options.with_indifferent_access
    type_field.field_options.delete(:section_present)
    type_field.save!
  end

  def test_deletion_of_decimal_field
    launch_ticket_field_revamp do
      name = "decimal_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field(name, :decimal, rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_decimal')
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_number_field
    launch_ticket_field_revamp do
      name = 'number' + Faker::Lorem.characters(rand(10..20))
      create_custom_field(name, :number, field_num: '01', required: rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_number')
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_text_field
    launch_ticket_field_revamp do
      name = "text_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field_dn(name, 'text', rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_text')
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_date_field
    launch_ticket_field_revamp do
      name = 'date' + Faker::Lorem.characters(rand(10..20))
      create_custom_field(name, :date, rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_date')
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_paragraph_field
    launch_ticket_field_revamp do
      name = "paragraph_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field_dn(name, 'paragraph', rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_paragraph')
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_checkbox_field
    launch_ticket_field_revamp do
      name = 'checkbox' + Faker::Lorem.characters(rand(10..20))
      create_custom_field(name, :checkbox, rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_checkbox')
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_dropdown_field
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field_dropdown(name, Faker::Lorem.words(6))
      tf = @account.ticket_fields.find_by_field_type('custom_dropdown')
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_nested_field
    launch_ticket_field_revamp do
      names = Faker::Lorem.words(3).map { |x| "nested_#{x}" }
      tf = create_dependent_custom_field(names, 2, rand(0..1) == 1)
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_dropdown_field_having_section
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
      tf = create_custom_field_dropdown_with_sections(name, DROPDOWN_CHOICES_TICKET_TYPE)
      create_section_fields(tf.id)
      delete :destroy, construct_params(id: tf.id)
      assert_response 400
      # delete section fields and then try deleting dropdown
      @account.ticket_fields.where(default: 0).each do |field|
        next if field.field_options['section_present'].present?
        delete :destroy, construct_params(id: field.id)
        assert_response 204
      end

      delete :destroy, construct_params(id: tf.id)
      assert_response 400
      @account.sections.destroy_all

      tf.field_options['section_present'] = false
      tf.save
      tf.reload

      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
    end
  end

  def test_deletion_of_default_field
    launch_ticket_field_revamp do
      tfs = @account.ticket_fields.where(default: 1)
      tfs.each do |field|
        delete :destroy, construct_params(id: field.id)
        assert_response 400
        assert @account.ticket_fields_with_nested_fields.find_by_id(field.id).present?
      end
      tfs1_count = @account.ticket_fields.where(default: 1).count
      assert_equal tfs.count, tfs1_count
    end
  end

  def test_deletion_of_invalid_field
    launch_ticket_field_revamp do
      delete :destroy, construct_params(id: -1)
      assert_response 404
    end
  end

  def test_deletion_of_archived_field
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(1..5))}"
      tf = create_custom_field_dropdown(name, Faker::Lorem.words(3))
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: true)
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.all_ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
      @account.rollback :archive_ticket_fields
    end
  end

  def test_deletion_of_nested_archived_field
    launch_ticket_field_revamp do
      names = Faker::Lorem.words(3).map { |x| "nf_#{x}" }
      tf = create_dependent_custom_field(names, 5, rand(0..1) == 1)
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: true)
      delete :destroy, construct_params(id: tf.id)
      assert_response 204
      assert @account.all_ticket_fields_with_nested_fields.find_by_id(tf.id).blank?
      @account.rollback :archive_ticket_fields
    end
  end

  def test_deletion_without_feature
    name = "decimal_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field(name, :decimal, rand(0..1) == 1)
    tf = @account.ticket_fields.find_by_field_type('custom_decimal')
    delete :destroy, construct_params(id: tf.id)
    assert_response 403
    assert_match 'Ticket Field Revamp', response.body

    launch_ticket_field_revamp do
      enable_custom_ticket_fields_feature {}
      delete :destroy, construct_params(id: tf.id)
      assert_response 403
      assert_match 'custom_ticket_fields', response.body
    end
  end

  def test_tickets_list_api_with_feature
    launch_ticket_field_revamp do
      create_ticket_fields_of_all_types
      get :index, controller_params(version: 'private')
      assert_response 200
    end
  end

  def test_tickets_list_api_without_feature
    create_ticket_fields_of_all_types
    get :index, controller_params(version: 'private')
    assert_response 403
    assert_match 'Ticket Field Revamp', response.body
    launch_ticket_field_revamp {}
    get :index, controller_params(version: 'private')
    assert_response 403
    assert_match 'Ticket Field Revamp', response.body
  end

  def test_show_dropdown_field
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field_dropdown(name, DROPDOWN_CHOICES_TICKET_TYPE)
      tf = @account.ticket_fields.find_by_field_type('custom_dropdown')
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_multiline_field
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field_dropdown(name, DROPDOWN_CHOICES_TICKET_TYPE)
      tf = @account.ticket_fields.find_by_field_type('custom_dropdown')
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_text_field
    launch_ticket_field_revamp do
      name = "text_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field_dn(name, 'text', rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_text')
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_date_field
    launch_ticket_field_revamp do
      name = 'date' + Faker::Lorem.characters(rand(10..20))
      create_custom_field(name, :date, rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_date')
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_dependent_field
    launch_ticket_field_revamp do
      names = Faker::Lorem.words(3).map { |x| "nested_#{x}" }
      tf = create_dependent_custom_field(names, 2, rand(0..1) == 1)
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_decimal_field
    launch_ticket_field_revamp do
      name = "decimal_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field(name, :decimal, rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_decimal')
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_number_field
    launch_ticket_field_revamp do
      name = 'number' + Faker::Lorem.characters(rand(10..20))
      create_custom_field(name, :number, field_num: '01', required: rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_number')
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_paragraph_field
    launch_ticket_field_revamp do
      name = "paragraph_#{Faker::Lorem.characters(rand(10..20))}"
      create_custom_field_dn(name, 'paragraph', rand(0..1) == 1)
      tf = @account.ticket_fields.find_by_field_type('custom_paragraph')
      get :show, construct_params(id: tf.id)
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_show_section_inside_dropdown_field
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
      tf = create_custom_field_dropdown_with_sections(name, DROPDOWN_CHOICES_TICKET_TYPE)
      create_section_fields(tf.id)
      tf.reload
      get :show, construct_params(id: tf.id, include: 'section')
      assert_response 200
      assert_json_match(custom_field_response(tf), response.body)
    end
  end

  def test_field_creation_without_feature
    post :create, construct_params({}, ticket_field_common_params)
    assert_response 403
    assert_match('Ticket Field Revamp', response.body)

    launch_ticket_field_revamp do
      enable_custom_ticket_fields_feature {}
      post :create, construct_params({}, ticket_field_common_params)
      assert_response 403
      assert_match('custom_ticket_fields', response.body)
    end
  end

  Helpdesk::Ticketfields::Constants::FIELD_COLUMN_MAPPING.except(*[:encrypted_text, :file, :date_time, :secure_text].concat(PICKLIST_TYPE_FIELDS)).each do |field_type, details|
    define_method("test_success_#{field_type}_field_creation") do
      params = ticket_field_common_params(type: "custom_#{field_type}")
      launch_ticket_field_revamp do
        post :create, construct_params({}, params)
        assert_response 201
        ticket_field = @account.ticket_fields_with_nested_fields.find(json_response(response)[:id])
        match_json(custom_field_response(ticket_field))
      end
    end
  end

  def test_archiving_field_without_feature
    launch_ticket_field_revamp do
      name = "text_#{Faker::Lorem.characters(rand(1..5))}"
      tf = create_custom_field_dn(name, 'text', rand(0..1) == 1)
      put :update, construct_params({ id: tf.id }, archived: true)
      assert_response 403
    end
  end

  def test_archiving_custom_field
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(1..5))}"
      tf = create_custom_field_dropdown(name, Faker::Lorem.words(3))
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: true)
      assert @account.all_ticket_fields_with_nested_fields.find(tf.id).present?
      assert @account.all_ticket_fields_with_nested_fields.find(tf.id).deleted
      @account.rollback :archive_ticket_fields
    end
  end

  def test_archiving_dependent_field
    launch_ticket_field_revamp do
      names = Faker::Lorem.words(3).map { |x| "nested_#{x}" }
      tf = create_dependent_custom_field(names, 9, rand(0..1) == 1)
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: true)
      assert @account.all_ticket_fields_with_nested_fields.find(tf.id).present?
      assert @account.all_ticket_fields_with_nested_fields.find(tf.id).deleted
      @account.rollback :archive_ticket_fields
    end
  end

  def test_archiving_default_field
    launch_ticket_field_revamp do
      tfs = @account.ticket_fields.where(default: 1)
      @account.launch :archive_ticket_fields
      tfs.each do |field|
        put :update, construct_params({ id: field.id }, archived: true)
        assert_response 400
        match_json([bad_request_error_pattern(
          field.name, "Default field '#{field.name}' can't be archived", code: 'invalid_value'
        )])
        assert !@account.all_ticket_fields_with_nested_fields.find_by_id(field.id).deleted
      end
      @account.rollback :archive_ticket_fields
    end
  end

  def test_archive_param_combined_with_other_params
    launch_ticket_field_revamp do
      name = "text_#{Faker::Lorem.characters(rand(1..3))}"
      tf = create_custom_field_dn(name, 'text', rand(0..1) == 1)
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: true, label: Faker::Lorem.characters(5))
      assert_response 400
      match_json([bad_request_error_pattern(
        tf.name, "'archived' parameter can not be combined with any other parameters", code: 'invalid_value'
      )])
      @account.rollback :archive_ticket_fields
    end
  end

  def test_allowed_values_on_archive_attribute
    launch_ticket_field_revamp do
      name = "text_#{Faker::Lorem.characters(rand(1..3))}"
      tf = create_custom_field_dn(name, 'text', rand(0..1) == 1)
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: Faker::Lorem.characters(5))
      assert_response 400
      match_json([bad_request_error_pattern(
        :archived, "It should be one of these values: 'true,false'", code: 'invalid_value'
      )])
      @account.rollback :archive_ticket_fields
    end
  end

  def test_archiving_ticket_field_has_section
    launch_ticket_field_revamp do
      name = "dropdown_#{Faker::Lorem.characters(rand(1..5))}"
      tf = create_custom_field_dropdown_with_sections(name, DROPDOWN_CHOICES_TICKET_TYPE)
      create_section_fields(tf.id)
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: true)
      assert_response 400
      match_json([bad_request_error_pattern(
        tf.name, "Ticket field '#{tf.name}' has sections, so it can't be archived", code: 'invalid_value'
      )])
      @account.rollback :archive_ticket_fields
    end
  end

  def test_updating_archived_ticket_field
    launch_ticket_field_revamp do
      name = "text_#{Faker::Lorem.characters(rand(1..3))}"
      tf = create_custom_field_dn(name, 'text', rand(0..1) == 1)
      @account.launch :archive_ticket_fields
      put :update, construct_params({ id: tf.id }, archived: true)
      put :update, construct_params({ id: tf.id }, label: Faker::Lorem.characters(rand(5..10)))
      assert_response 400
      match_json([bad_request_error_pattern(
        tf.name, "'Update' operation can not be performed on archived fields", code: 'invalid_value'
      )])
      @account.rollback :archive_ticket_fields
    end
  end

  def test_success_encrypted_text_field_creation
    params = ticket_field_common_params(type: 'encrypted_text')
    launch_ticket_field_revamp do
      stubs_hippa_and_custom_encrypted_field do
        post :create, construct_params({}, params)
        ticket_field = @account.ticket_fields_with_nested_fields.find(json_response(response)[:id])
        assert_response 201
        match_json(custom_field_response(ticket_field))
      end
    end
    @account.revoke_feature :custom_encrypted_fields
  end

  def test_encrypted_text_field_creation_without_feature
    params = ticket_field_common_params(type: 'encrypted_text')
    launch_ticket_field_revamp do
      post :create, construct_params({}, params)
      assert_response 403
    end
  end

  def test_create_with_invalid_type
    params = ticket_field_common_params(type: 'invalid_type')
    launch_ticket_field_revamp do
      post :create, construct_params({}, params)
      assert_response 400
      assert_match('invalid_value', response.body)
    end
  end

  def test_create_with_invalid_position
    params = ticket_field_common_params(position: '51')
    launch_ticket_field_revamp do
      post :create, construct_params({}, params)
      assert_response 400
      assert_match('datatype_mismatch', response.body)
    end
  end

  def test_create_with_invalid_labels
    params = ticket_field_common_params(label: 1, label_for_customers: 1)
    launch_ticket_field_revamp do
      post :create, construct_params({}, params)
      assert_response 400
      assert_match('datatype_mismatch', response.body)
    end
  end

  def test_create_with_labels_missing
    params = { position: 1, type: 'custom_text' }
    launch_ticket_field_revamp do
      post :create, construct_params({}, params)
      assert_response 400
      assert_match('invalid_value', response.body)
    end
  end

  # def test_create_with_duplicate_label
  #   params = ticket_field_common_params({label: 'xyz'})
  #   launch_ticket_field_revamp do
  #     create_custom_field(params[:label], 'text')
  #     post :create, construct_params({}, params)
  #     assert_response 400
  #     assert_match("already exist", response.body)
  #   end
  # end

  # def test_create_with_duplicate_label_for_customer
  #   params = ticket_field_common_params({label_for_customers: 'xyz'})
  #   launch_ticket_field_revamp do
  #     create_custom_field(params[:label_for_customers], 'text')
  #     post :create, construct_params({}, params)
  #     assert_response 400
  #     assert_match("already exist", response.body)
  #   end
  # end

  Helpdesk::Ticketfields::Constants::FIELD_COLUMN_MAPPING.except(*[:encrypted_text, :file, :text, :date_time, :secure_text].concat(PICKLIST_TYPE_FIELDS)).each do |field_type, details|
    define_method("test_create_custom_#{field_type}_field_limit_exceeded") do
      launch_ticket_field_revamp do
        method_name = field_type.in?(DENORMALIZED_FIELDS) ? 'create_custom_field_dn' : 'create_custom_field'
        details[2].times do |i|
          safe_send(method_name, "custom_#{field_type}_#{i}", field_type.to_s, format('%02d', i + 1))
        end
        field_type = "custom_#{field_type}"
        params = ticket_field_common_params(type: field_type)
        post :create, construct_params({}, params)
        assert_response 400
        assert_match('You have exceeded the maximum limit for this type of field', response.body)
      end
    end
  end

  def test_create_encrypted_field_limit_exceeded
    field_type = :encrypted_text
    limit = Helpdesk::Ticketfields::Constants::FIELD_COLUMN_MAPPING[field_type][2]
    launch_ticket_field_revamp do
      limit.times do |i|
        create_custom_field_dn("custom_#{field_type}_#{i}", field_type.to_s, format('%02d', i + 1))
      end
      params = ticket_field_common_params(type: field_type.to_s)
      post :create, construct_params({}, params)
      assert_response 403
      stubs_hippa_and_custom_encrypted_field do
        post :create, construct_params({}, params)
        assert_match('You have exceeded the maximum limit for this type of field.', response.body)
      end
    end
  end

  def test_create_secure_text_field
    params = ticket_field_common_params(type: 'secure_text')
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    launch_ticket_field_revamp do
      post :create, construct_params({}, params)
      assert_response 201
      ticket_field = @account.ticket_fields.find(json_response(response)[:id])
      match_json(custom_field_response(ticket_field))
    end
  ensure
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_create_secure_text_field_without_feature
    params = ticket_field_common_params(type: 'secure_text')
    launch_ticket_field_revamp do
      post :create, construct_params({}, params)
      assert_response 403
    end
  end

  def test_create_secure_text_field_limit_exceeded
    field_type = :secure_text
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    limit = Helpdesk::Ticketfields::Constants::FIELD_COLUMN_MAPPING[field_type][2]
    launch_ticket_field_revamp do
      limit.times do |i|
        create_custom_field_dn("custom_#{field_type}_#{i}", field_type.to_s, format('%02d', i + 1))
      end
      params = ticket_field_common_params(type: field_type.to_s)
      post :create, construct_params({}, params)
      assert_response 400
      assert_match('You have exceeded the maximum limit for this type of field.', response.body)
    end
  ensure
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_ticket_field_index_with_secure_text_field
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    launch_ticket_field_revamp do
      name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
      secure_text_field = create_custom_field_dn(name, 'secure_text')
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      secure_text_field_in_index_call = response.find { |x| x['id'] == secure_text_field.id }
      assert_not_nil secure_text_field_in_index_call
      assert_equal secure_text_field_in_index_call['type'], "secure_text"
    end
  ensure
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_fetch_non_secure_ticket_fields
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    launch_ticket_field_revamp do
      name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
      secure_text_field = create_custom_field_dn(name, 'secure_text')
      @account.reload
      non_secure_fields = @account.ticket_fields.non_secure_fields
      assert_equal false, non_secure_fields.include?(secure_text_field)
    end
  ensure
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_updating_type_field_in_sprout_plan
    launch_ticket_field_revamp do
      type_field = @account.ticket_fields.find_by_field_type('default_ticket_type')
      type_field_choice_position = type_field.picklist_values.count
      Account.current.stubs(:custom_ticket_fields_enabled?).returns(false)
      put :update, construct_params({ id: type_field.id }, choices: [{ value: Faker::Lorem.characters(5), position: type_field_choice_position + 1 }])
      assert_response 200
    end
  ensure
    Account.current.unstub(:custom_ticket_fields_enabled?)
  end

  def test_adding_status_choice_in_sprout_plan
    launch_ticket_field_revamp do
      field = @account.ticket_fields.find_by_field_type('default_status')
      field_choice_position = field.ticket_statuses.reject(&:deleted?).count
      Account.current.stubs(:custom_ticket_fields_enabled?).returns(false)
      put :update, construct_params({ id: field.id }, choices: [{ value: Faker::Lorem.characters(5), position: field_choice_position + 1 }])
      assert_response 400
    end
  ensure
    Account.current.unstub(:custom_ticket_fields_enabled?)
  end

  def test_updating_status_choice_in_sprout_plan
    launch_ticket_field_revamp do
      field = @account.ticket_fields.find_by_field_type('default_status')
      pending_status = field.ticket_statuses.find_by_name('Pending')
      Account.current.stubs(:custom_ticket_fields_enabled?).returns(false)
      put :update, construct_params({ id: field.id }, choices: [{ id: pending_status.status_id, stop_sla_timer: !pending_status.stop_sla_timer }])
      assert_response 200
    end
  ensure
    Account.current.unstub(:custom_ticket_fields_enabled?)
  end

  def test_update_status_choice_check_position
    launch_ticket_field_revamp do
      field = @account.ticket_fields.find_by_field_type('default_status')
      waiting_on_customer = field.ticket_statuses.find_by_name('Waiting on Customer')
      old_position = waiting_on_customer.position
      put :update, construct_params({ id: field.id }, choices: [{ id: waiting_on_customer.status_id, stop_sla_timer: !waiting_on_customer.stop_sla_timer }])
      waiting_on_customer.reload
      assert_equal waiting_on_customer.position, old_position
    end
  end

  def test_update_status_position_change
    launch_ticket_field_revamp do
      field = @account.ticket_fields.find_by_field_type('default_status')
      waiting_on_customer = field.ticket_statuses.find_by_name('Waiting on Customer')
      new_position = rand(1..4)
      put :update, construct_params({ id: field.id }, choices: [{ id: waiting_on_customer.status_id, position: new_position }])
      waiting_on_customer.reload
      assert_equal waiting_on_customer.position, new_position
    end
  end

  def test_sanitize_malicious_ticket_field_name
    launch_ticket_field_revamp do
      name1 = "<script>alert(‘#{Faker::Lorem.characters(rand(1..4))}’)</script>"
      tf1 = create_custom_field_dropdown(name1, Faker::Lorem.words(6))
      name2 = "<title>#{Faker::Lorem.characters(rand(5..10))}</title>"
      tf2 = create_custom_field_dn(name2, 'text', rand(0..1) == 1)
      field1 = @account.ticket_fields_with_nested_fields.find(tf1.id)
      field2 = @account.ticket_fields_with_nested_fields.find(tf2.id)
      assert_equal field1.label, RailsFullSanitizer.sanitize(name1)
      assert_equal field2.label, RailsFullSanitizer.sanitize(name2)
      assert_equal field1.label_in_portal, RailsFullSanitizer.sanitize(name1)
      assert_equal field2.label_in_portal, RailsFullSanitizer.sanitize(name2)
    end
  end

  def test_sanitization_of_nested_field_names
    launch_ticket_field_revamp do
      names = Faker::Lorem.words(3).map { |x| "<script>alert(‘#{x}’)</script>" }
      tf = create_dependent_custom_field(names, 13, rand(0..1) == 1)
      parent_field = @account.all_ticket_fields_with_nested_fields.find(tf.id)
      child_fields = parent_field.nested_ticket_fields
      assert_equal parent_field.label, RailsFullSanitizer.sanitize(names[0])
      assert_equal parent_field.label_in_portal, RailsFullSanitizer.sanitize(names[0])
      assert_equal child_fields[0].label, RailsFullSanitizer.sanitize(names[1])
      assert_equal child_fields[0].label_in_portal, RailsFullSanitizer.sanitize(names[1])
      assert_equal child_fields[1].label, RailsFullSanitizer.sanitize(names[2])
      assert_equal child_fields[1].label_in_portal, RailsFullSanitizer.sanitize(names[2])
    end
  end

  def test_deletion_of_secure_text_field
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    ::Tickets::VaultDataCleanupWorker.jobs.clear
    launch_ticket_field_revamp do
      name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
      secure_text_field = create_custom_field_dn(name, 'secure_text')
      delete :destroy, construct_params(id: secure_text_field.id)
      assert_response 204
      assert @account.ticket_fields.find_by_id(secure_text_field.id).blank?
      assert_equal 1, ::Tickets::VaultDataCleanupWorker.jobs.size
      args = ::Tickets::VaultDataCleanupWorker.jobs.first.deep_symbolize_keys[:args][0]
      assert_equal args[:field_names], [TicketDecorator.display_name(secure_text_field.name)]
    end
  ensure
    ::Tickets::VaultDataCleanupWorker.jobs.clear
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_updating_source_choice
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 1'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 15, icon_id: 101 }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_equal source.position, 15
      assert_equal source.meta[:icon_id], 101
      put :update, construct_params({ id: field.id }, choices: [{ id: source.account_choice_id, icon_id: 110 }])
      assert_response 200
      source.reload
      assert_equal source.meta[:icon_id], 110
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_update_default_source_choice
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      put :update, construct_params({ id: field.id }, choices: [{ id: 3, icon_id: 114 }])
      assert_response 400
      match_json([bad_request_error_pattern('id', :default_field_modified, field: :choice)])
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_update_source_choice_duplicate_label
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 3'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 15, icon_id: 101 }, { label: label, position: 16, icon_id: 111 }]
      )
      assert_response 400
      match_json([bad_request_error_pattern('Source[choices]', :duplicate_choice_for_ticket_field, field: 'label', value: label)])
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_update_source_choice_default_choice_position
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 4'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 2, icon_id: 101 }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_equal 2, source.position
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_update_source_choice_lua_sha_failure
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      Redis::BaseError.any_instance.stubs(:message).returns('NOSCRIPT No matching script')
      $redis_display_id.stubs(:evalsha).raises(Redis::BaseError)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 5'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 20, icon_id: 101 }]
      )
      assert_response 200
    end
  ensure
    $redis_display_id.unstub(:evalsha)
    Redis::BaseError.any_instance.unstub(:message)
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_update_source_choice_with_default_icon_id
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 6'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 22, icon_id: 2 }]
      )
      assert_response 400
      match_json([bad_request_error_pattern('choices', :invalid_value_for_icon_id, range: '101 to 114')])
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_create_source_choice_with_maximum_length
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = Faker::Lorem.characters
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 22, icon_id: 101 }]
      )
      assert_response 400
      match_json([bad_request_error_pattern(:label, 'is too long (maximum is 50 characters)')])
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_updating_source_choice_with_maximum_length
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 7'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 15, icon_id: 101 }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_equal source.position, 15
      assert_equal source.meta[:icon_id], 101
      put :update, construct_params({ id: field.id }, choices: [{ id: source.account_choice_id, label: Faker::Lorem.characters }])
      assert_response 400
      match_json([bad_request_error_pattern(:label, 'is too long (maximum is 50 characters)')])
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_source_create_with_max_limit
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      create_n_custom_sources(Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT - 1)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 8'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 25, icon_id: 102 }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_not_nil source
      assert_equal source.position, 25
      assert_equal source.meta[:icon_id], 102
      label = 'source test 9'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 31, icon_id: 105 }]
      )
      assert_response 400
      match_json([bad_request_error_pattern(field.label, :ticket_choices_exceeded_limit, limit: Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT, field_type: field.label, code: :exceeded_limit)])
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_source_update_with_max_limit
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      create_n_custom_sources(Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT - 1)
      deleted_source1 = create_custom_source(deleted: true)
      assert_not_nil deleted_source1
      assert deleted_source1.deleted
      deleted_source2 = create_custom_source(deleted: true)
      assert_not_nil deleted_source2
      assert deleted_source2.deleted
      field = @account.ticket_fields.where(field_type: 'default_source').first
      put :update, construct_params(
        { id: field.id },
        choices: [{ id: deleted_source1.account_choice_id, deleted: false }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(account_choice_id: deleted_source1.account_choice_id).first
      assert_not_nil source
      refute source.deleted
      put :update, construct_params(
        { id: field.id },
        choices: [{ id: deleted_source2.account_choice_id, deleted: false }]
      )
      assert_response 400
      match_json([bad_request_error_pattern(field.label, :ticket_choices_exceeded_limit, limit: Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT, field_type: field.label, code: :exceeded_limit)])
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_source_choice_delete_then_create_after_max_limit_reached
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      create_n_custom_sources(Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 10'
      put :update, construct_params(
        { id: field.id },
        choices: [{ id: @account.helpdesk_sources.last.account_choice_id, deleted: true }]
      )
      assert_response 200
      assert @account.helpdesk_sources.last.deleted
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 26, icon_id: 107 }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_not_nil source
      assert_equal source.position, 26
      assert_equal source.meta[:icon_id], 107
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_source_choice_max_limit_with_delete_and_create
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      create_n_custom_sources(Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 11'
      deleted_source_id = @account.helpdesk_sources.last.account_choice_id
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 37, icon_id: 110 }, { id: deleted_source_id, deleted: true }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_not_nil source
      assert_equal source.position, 37
      assert_equal source.meta[:icon_id], 110
      deleted_source = @account.helpdesk_sources.where(account_choice_id: deleted_source_id).first
      assert_not_nil deleted_source
      assert deleted_source.deleted
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_source_choice_max_limit_with_multiple_combinations
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      create_n_custom_sources(Helpdesk::Source::CUSTOM_SOURCE_MAX_ACTIVE_COUNT)
      deleted_source = create_custom_source(deleted: true)
      assert_not_nil deleted_source
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 12'
      custom_sources = @account.helpdesk_sources.visible.custom
      source_to_del1 = custom_sources.first
      source_to_del2 = custom_sources.second
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 40, icon_id: 104 }, { id: source_to_del1.account_choice_id, deleted: true },
                  { id: source_to_del2.account_choice_id, deleted: true }, { id: deleted_source.account_choice_id, deleted: false }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_not_nil source
      source = @account.helpdesk_sources.where(account_choice_id: source_to_del1.account_choice_id).first
      assert source.deleted
      source = @account.helpdesk_sources.where(account_choice_id: source_to_del2.account_choice_id).first
      assert source.deleted
      source = @account.helpdesk_sources.where(account_choice_id: deleted_source.account_choice_id).first
      refute source.deleted
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_updating_default_source_position
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      source = Account.current.helpdesk_sources.where(account_choice_id: 3).first
      put :update, construct_params({ id: field.id }, choices: [{ id: 3, position: 15 }])
      assert_response 200
      source.reload
      assert_equal 15, source.position
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  def test_source_choice_creation_without_icon
    launch_ticket_field_revamp do
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      field = @account.ticket_fields.where(field_type: 'default_source').first
      label = 'source test 1'
      put :update, construct_params(
        { id: field.id },
        choices: [{ label: label, position: 25 }]
      )
      assert_response 200
      source = @account.helpdesk_sources.where(name: label).first
      assert_equal source.meta[:icon_id], 101
    end
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end
end
