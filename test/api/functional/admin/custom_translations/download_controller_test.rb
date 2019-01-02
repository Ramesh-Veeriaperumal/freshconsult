require_relative '../../../test_helper'
class Admin::CustomTranslations::DownloadControllerTest < ActionController::TestCase
  include TicketFieldsTestHelper
  CHOICES = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'].freeze

  def test_custom_ticket_fields_count
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields'].count
    acc_tkt_fields = Account.current.ticket_fields_with_nested_fields.where(default: false).count
    assert acc_tkt_fields + 2 == ticket_fields
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_ticket_field_type
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?('ticket_type')
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_ticket_field_status
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?('status')
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_dropdown
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    custom_dropdown = create_custom_field_dropdown('test_custom_dropdown', CHOICES)
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(custom_dropdown.name)
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_field_number
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    field = create_custom_field('test_custom_number', 'number')
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_field_checkbox
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    field = create_custom_field('test_custom_checkbox', 'checkbox')
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_field_decimal
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    field = create_custom_field('test_custom_decimal', 'decimal')
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_field_text
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    field = create_custom_field('test_custom_text', 'text')
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_field_paragraph
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    field = create_custom_field('test_custom_paragraph', 'paragraph')
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_field_date
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    field = create_custom_field('test_custom_date', 'date')
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_status
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    status = create_custom_status
    get :primary, construct_params({})
    primary_lang = Account.current.language
    status_choices = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']['status']['choices']
    assert status_choices["choice_#{status.status_id}"] == status.name
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_nested_field
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?('test_custom_country_1')
    assert ticket_fields.include?('test_custom_state_1')
    assert ticket_fields.include?('test_custom_city_1')
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_custom_nested_field_choices
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    nested_field = create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    nested_field_level2 = Account.current.ticket_fields_with_nested_fields.find_by_name('test_custom_state_1')
    nested_field_level3 = Account.current.ticket_fields_with_nested_fields.find_by_name('test_custom_city_1')
    get :primary, construct_params({})
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields['test_custom_country_1']['choices'] == nested_field.fetch_custom_field_choices
    assert ticket_fields['test_custom_state_1']['choices'] == nested_field_level2.fetch_custom_field_choices
    assert ticket_fields['test_custom_city_1']['choices'] == nested_field_level3.fetch_custom_field_choices
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_header
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    get :primary, construct_params({})
    assert response.header.include?('Content-Disposition')
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_check_field_which_doesnot_have_choices
    field = Account.current.ticket_fields.find_by_name('agent')
    choices = field.fetch_custom_field_choices
    assert choices.empty?
  end

  def test_change_primary_language
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    Account.current.main_portal.language = 'fr'
    Account.current.main_portal.save
    get :primary, construct_params({})
    assert YAML.load(response.body)['fr'].present?
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_primary_file_name
    Account.current.add_feature(:custom_translations)
    Account.current.launch :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id)
    get :primary, construct_params({})
    assert response.header['Content-Disposition'].include?('primary.yml')
  ensure
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :redis_picklist_id
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end
end
