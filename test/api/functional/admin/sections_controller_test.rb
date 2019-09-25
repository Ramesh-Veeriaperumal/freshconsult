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

      type_field = @account.ticket_fields_with_nested_fields.find_by_id(3)
      assert type_field.field_options[:section_present].present?

      section = @account.sections.first
      delete :destroy, construct_params(id: section.id, ticket_field_id: 3)
      assert_response 204

      assert @account.sections.blank?

      assert @account.ticket_fields_with_nested_fields.find_by_id(3).field_options['section_present'].blank?

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
end
