require_relative '../../test_helper.rb'
require Rails.root.join('test/api/helpers/ticket_fields_test_helper')
require Rails.root.join('test/api/helpers/test_case_methods')
require Rails.root.join('test/api/helpers/admin/ticket_field_helper')

require 'faker'
class Admin::SectionsControllerTest < ActionController::TestCase
  include TestCaseMethods
  include TicketFieldsTestHelper
  include Admin::TicketFieldHelper

  def setup
    super
    clean_db
    create_section_fields
  end

  def teardown
    clean_db
    super
  end

  def clean_db
    @account.sections.destroy_all
    @account.ticket_fields.where(default: 0).destroy_all
  end

  DROPDOWN_CHOICES_TICKET_TYPE = %w[Question Problem Incident].freeze

  def test_deletion_of_section
    launch_ticket_field_revamp do
      section = @account.sections.first
      delete :destroy, construct_params(id: section.id, ticket_field_id: 3)
      assert_response 400
      assert_match 'existing_section_fields', response.body

      @account.ticket_fields_with_nested_fields.where(default: 0).each do |tf|
        if tf.field_options.present? && tf.field_options[:section].present?
          tf.destroy
        end
      end

      delete :destroy, construct_params(id: section.id, ticket_field_id: 3)
      assert_response 204
      assert @account.sections.find_by_id(section.id).blank?

      type_field = @account.ticket_fields_with_nested_fields.reload.find_by_id(3)
      assert type_field.field_options[:section_present].present?

      section = @account.sections.reload.first
      delete :destroy, construct_params(id: section.id, ticket_field_id: 3)
      assert_response 204

      assert @account.sections.reload.blank?

      assert @account.ticket_fields_with_nested_fields.reload.find_by_id(3).field_options['section_present'].blank?
    end
  end

  def test_feature_check_for_sections
    section = @account.sections.first
    delete :destroy, construct_params(id: section.id, ticket_field_id: 3)
    assert_response 403

    launch_ticket_field_revamp do
      @account.revoke_feature :multi_dynamic_sections
      @account.revoke_feature :dynamic_sections

      delete :destroy, construct_params(id: section.id, ticket_field_id: 3)
      assert_response 403
    end
  end

  def test_section_not_found
    launch_ticket_field_revamp do
      section = @account.sections.first
      delete :destroy, construct_params(id: -1, ticket_field_id: 3)
      assert_response 404
      get :show, construct_params(id: -1, ticket_field_id: 3)
      assert_response 404
      put :update, construct_params({ id: -1, ticket_field_id: 3 }, label: 'str')
      assert_response 404
    end
  end

  def test_section_index
    launch_ticket_field_revamp do
      @account.add_features(:dynamic_sections)
      get :index, controller_params(ticket_field_id: 3)
      assert_response 200
      match_json(sections(Account.current.ticket_fields.find(3))[:sections])
    end
  end

  def test_section_show
    launch_ticket_field_revamp do
      @account.add_features(:dynamic_sections)
      section = @account.sections.first
      get :show, controller_params(ticket_field_id: section.ticket_field_id, id: section.id)
      assert_response 200
      match_json(sections(@account.ticket_fields.find(3))[:sections].find { |s| s[:id] == section.id })
    end
  end

  def test_create_section_params_datatype_mismatch
    launch_ticket_field_revamp do
      post :create, construct_params({ ticket_field_id: 3 }, label: 1, choice_ids: [5])
      assert_response 400
      match_json([bad_request_error_pattern(:label, 'Value set is of type Integer.It should be a/an String', code: 'datatype_mismatch')])

      post :create, construct_params({ ticket_field_id: 3 }, label: 'label', choice_ids: 'string')
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, 'Value set is of type String.It should be a/an Array', code: 'datatype_mismatch')])

      post :create, construct_params({ ticket_field_id: 3 }, label: 'label', choice_ids: ['string'])
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, 'It should contain elements of type Positive Integer only', code: 'datatype_mismatch')])
    end
  end

  def test_create_section_missing_params
    launch_ticket_field_revamp do
      post :create, construct_params({ ticket_field_id: 3 }, choice_ids: [5])
      assert_response 400
      match_json([bad_request_error_pattern(:label, "can't be blank", code: 'invalid_value')])

      post :create, construct_params({ ticket_field_id: 3 }, label: 'label')
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, "can't be blank", code: 'invalid_value')])
    end
  end

  def test_create_section_invalid_params
    launch_ticket_field_revamp do
      section = @account.sections.first
      choice_id = @account.picklist_values.where(ticket_field_id: 3).last.picklist_id

      post :create, construct_params({ ticket_field_id: 3 }, label: '', choice_ids: [choice_id])
      assert_response 400
      match_json([bad_request_error_pattern(:label, "can't be blank", code: 'invalid_value')])

      post :create, construct_params({ ticket_field_id: 3 }, label: section.label, choice_ids: [choice_id])
      assert_response 400
      match_json([bad_request_error_pattern(:label, :duplicate_name_in_sections, label: section.label)])

      post :create, construct_params({ ticket_field_id: 3 }, label: 'label', choice_ids: [])
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, "can't be blank", code: 'invalid_value')])

      post :create, construct_params({ ticket_field_id: 3 }, label: 'label', choice_ids: [100])
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, :absent_in_db, code: 'invalid_value', resource: :choice, attribute: 'choice_ids 100')])

      post :create, construct_params({ ticket_field_id: 3 }, label: 'label', choice_ids: section.section_picklist_mappings.pluck('picklist_id'))
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, :choice_id_taken, code: 'invalid_value', id: section.section_picklist_mappings.pluck('picklist_id').join(', '))])
    end
  end

  def test_section_create
    launch_ticket_field_revamp do
      @account.add_features(:dynamic_sections)
      choice_id = @account.picklist_values.where(ticket_field_id: 3).last.picklist_id

      post :create, construct_params({ ticket_field_id: 3 }, label: 'label', choice_ids: [choice_id])
      assert_response 201
      match_json(sections(@account.ticket_fields.find(@account.sections.last.ticket_field_id))[:sections].find { |s| s[:id] == @account.sections.last.id })
    end
  end

  def test_update_section_params_datatype_mismatch
    launch_ticket_field_revamp do
      @account.add_features(:dynamic_sections)
      section = @account.sections.first

      put :update, construct_params({ id: section.id, ticket_field_id: 3 }, label: 1)
      assert_response 400
      match_json([bad_request_error_pattern(:label, 'Value set is of type Integer.It should be a/an String', code: 'datatype_mismatch')])

      put :update, construct_params({ id: section.id, ticket_field_id: 3 }, choice_ids: 'string')
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, 'Value set is of type String.It should be a/an Array', code: 'datatype_mismatch')])

      put :update, construct_params({ id: section.id, ticket_field_id: 3 }, choice_ids: ['string'])
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, 'It should contain elements of type Positive Integer only', code: 'datatype_mismatch')])
    end
  end

  def test_update_section_invalid_params
    launch_ticket_field_revamp do
      @account.add_features(:dynamic_sections)
      section = @account.sections.first

      put :update, construct_params({ ticket_field_id: section.ticket_field_id, id: section.id }, label: '')
      assert_response 400
      match_json([bad_request_error_pattern(:label, 'It should not be blank as this is a mandatory field', code: 'invalid_value')])

      put :update, construct_params({ ticket_field_id: section.ticket_field_id, id: section.id }, label: @account.sections.last.label)
      assert_response 400
      match_json([bad_request_error_pattern(:label, :duplicate_name_in_sections, label: @account.sections.last.label)])

      put :update, construct_params({ ticket_field_id: section.ticket_field_id, id: section.id }, choice_ids: [])
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, 'It should not be blank as this is a mandatory field', code: 'invalid_value')])

      put :update, construct_params({ ticket_field_id: 3, id: section.id }, choice_ids: [100])
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, :absent_in_db, code: 'invalid_value', resource: :choice, attribute: 'choice_ids 100')])

      put :update, construct_params({ ticket_field_id: section.ticket_field_id, id: section.id }, choice_ids: @account.sections.last.section_picklist_mappings.pluck('picklist_id'))
      assert_response 400
      match_json([bad_request_error_pattern(:choice_ids, :choice_id_taken, code: 'invalid_value', id: @account.sections.last.section_picklist_mappings.pluck('picklist_id').join(', '))])
    end
  end

  def test_section_update
    launch_ticket_field_revamp do
      @account.add_features(:dynamic_sections)
      section = @account.sections.first

      put :update, construct_params({ ticket_field_id: section.ticket_field_id, id: section.id }, label: 'label')
      assert_response 200
      match_json(sections(@account.ticket_fields.find(section.ticket_field_id))[:sections].find { |s| s[:id] == section.id })

      put :update, construct_params({ ticket_field_id: section.ticket_field_id, id: section.id }, choice_ids: [5])
      assert_response 200
      match_json(sections(@account.ticket_fields.find(section.ticket_field_id))[:sections].find { |s| s[:id] == section.id })
    end
  end
end
