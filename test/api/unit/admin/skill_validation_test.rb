require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../../test/api/helpers/admin/skills_test_helper'
class Admin::SkillValidationTest < ActionView::TestCase
  include Admin::SkillConstants
  include Admin::SkillsTestHelper
  include Admin::CustomFieldHelper

  # default valid skill validation
  CONDITION_FIELDS.each_pair do |resource_type, field_names|
    field_names.each do |field_name|
      define_method "test_skill_valid_param_default_#{resource_type}_#{field_name}_field" do
        Account.stubs(:current).returns(Account.first)
        params = construct_skill_param(resource_type, field_name)
        validation = skill_validation_class.new(params, custom_field_hash, Account.current.agents.pluck_all(:user_id))
        assert validation.valid?
      end
    end
  end

  INVALID_SKILL_PARAMS.each_with_index do |invalid_param, index|
    define_method "test_skill_invalid#{index.to_s}_param" do
      Account.stubs(:current).returns(Account.first)
      validation = skill_validation_class.new(invalid_param, custom_field_hash, Account.current.agents.pluck_all(:user_id))
      validation.invalid?
    end
  end

  private

    def skill_validation_class
      'Admin::SkillValidation'.constantize
    end

    def custom_field_hash
      ticket_fields_condition_hash = custom_condition_ticket_field[1].select { |field| [:nested_field, :object_id].include? field[:field_type] }
      contact_fields_condition_hash = custom_condition_contact[1].select { |field| [:object_id, :dropdown].include? field[:field_type] }
      company_fields_condition_hash = custom_condition_company[1].select { |field| [:object_id, :dropdown].include? field[:field_type] }
      { ticket: [ticket_fields_condition_hash.map { |field_hash| field_hash[:name] }, ticket_fields_condition_hash],
        contact: [contact_fields_condition_hash.map { |field_hash| field_hash[:name] }, contact_fields_condition_hash],
        company: [company_fields_condition_hash.map { |field_hash| field_hash[:name] }, company_fields_condition_hash] }
    end
end