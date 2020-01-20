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
  end

  def teardown
    clean_db
    super
  end

  def clean_db
    @account.ticket_fields.where(default: 0).destroy_all
    @account.ticket_fields.update_all(field_options: {})
    @account.sections.destroy_all
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
      names = Faker::Lorem.words(3).map {|x| "nested_#{x}"}
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

  def test_deletion_without_feature
    name = "decimal_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field(name, :decimal, rand(0..1) == 1)
    tf = @account.ticket_fields.find_by_field_type('custom_decimal')
    delete :destroy, construct_params(id: tf.id)
    assert_response 403
    assert_match 'Ticket Field Revamp', response.body

    launch_ticket_field_revamp do
      @account.revoke_feature :custom_ticket_fields
      delete :destroy, construct_params(id: tf.id)
      assert_response 403
      assert_match 'custom_ticket_fields', response.body
      @account.add_feature :custom_ticket_fields
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
    launch_ticket_field_revamp do
      @account.rollback :ticket_field_revamp
      get :index, controller_params(version: 'private')
      assert_response 403
      assert_match 'Ticket Field Revamp', response.body
    end
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
      names = Faker::Lorem.words(3).map {|x| "nested_#{x}"}
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
      @account.revoke_feature :custom_ticket_fields
      post :create, construct_params({}, ticket_field_common_params)
      assert_response 403
      assert_match('custom_ticket_fields', response.body)
      @account.add_feature :custom_ticket_fields
    end
  end

  Helpdesk::Ticketfields::Constants::FIELD_COLUMN_MAPPING.except(*[:encrypted_text, :file, :date_time].concat(PICKLIST_TYPE_FIELDS)).each do |field_type, details|
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
    params = {position: 1, type: 'custom_text'}
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

  Helpdesk::Ticketfields::Constants::FIELD_COLUMN_MAPPING.except(*[:encrypted_text, :file, :text, :date_time].concat(PICKLIST_TYPE_FIELDS)).each do |field_type, details|
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
end
