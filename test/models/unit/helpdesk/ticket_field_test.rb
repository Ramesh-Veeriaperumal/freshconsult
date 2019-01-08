require_relative '../../test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class TicketFieldTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper

  def test_duplicate_ticket_status
    locale = I18n.locale
    I18n.locale = 'de'
    last_position_id = @account.ticket_statuses.last.position
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'open', 'open', last_position_id))
    assert_equal last_position_id, @account.ticket_statuses.last.position
    ensure
      I18n.locale = locale
  end

  def test_translate_key_value
    locale = I18n.locale
    I18n.locale = 'de'
    last_position_id = @account.ticket_statuses.last.position
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'support', 'support',last_position_id))
    assert_equal last_position_id+1, @account.ticket_statuses.last.position
    ensure
      I18n.locale = locale
  end
  
  def test_change_status_customer_name
    locale = I18n.locale
    I18n.locale = 'de'
    prev_status = @account.ticket_statuses.where(status_id: 2).first
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'open', 'Edited', prev_status.position))
    curr_status = @account.ticket_statuses.where(status_id: 2).first
    assert_not_equal prev_status.customer_display_name, curr_status.customer_display_name
    ensure
      I18n.locale = locale
  end

  def test_translated_label_in_portal_when_custom_translations_not_enabled
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    assert_equal status_custom_field.translated_label_in_portal, status_custom_field.label_in_portal
    dropdown_field = create_custom_field_dropdown
    assert_equal dropdown_field.translated_label_in_portal, dropdown_field.label_in_portal
    dependent_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
    assert_equal dependent_field.translated_label_in_portal, dependent_field.label_in_portal
    fields = dependent_field.nested_ticket_fields
    assert_equal fields.first.translated_label_in_portal, fields.first.label_in_portal
    assert_equal fields.last.translated_label_in_portal, fields.last.label_in_portal
    type_field = @account.ticket_fields.find_by_field_type('default_ticket_type')
    assert_equal type_field.translated_label_in_portal, type_field.label_in_portal
  end

  def test_status_field_when_custom_translations_enabled_and_user_present
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    User.first.make_current
    User.any_instance.stubs(:language).returns("fr")
    status_field = Account.current.ticket_fields.find_by_field_type(:default_status)
    status = create_custom_status 
    status = Account.current.ticket_statuses.last
    ct = create_custom_translation(status_field.id,"fr",status_field.name,status_field.label_in_portal,[[status.status_id,status.name]]).translations
    assert_equal status_field.translated_label_in_portal, ct["customer_label"]
    assert_equal Hash[Account.current.ticket_fields.find(5).visible_status_choices][ct["customer_choices"]["choice_#{status.status_id}"]], status.status_id
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:supported_languages)
    User.reset_current_user
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

  def test_status_field_when_custom_translations_enabled_and_user_not_present
    locale = I18n.locale
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    I18n.locale = :fr
    status_field = Account.current.ticket_fields.find_by_field_type(:default_status)
    status = create_custom_status 
    status = Account.current.ticket_statuses.last
    ct = create_custom_translation(status_field.id,"fr",status_field.name,status_field.label_in_portal,[[status.status_id,status.name]]).translations
    assert_equal status_field.translated_label_in_portal, ct["customer_label"]
    assert_equal Hash[Account.current.ticket_fields.find(5).visible_status_choices][ct["customer_choices"]["choice_#{status.status_id}"]], status.status_id
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:supported_languages)
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    I18n.locale = locale
  end

  def test_status_field_when_custom_translations_enabled_and_user_present_with_different_language
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    User.any_instance.stubs(:language).returns("en")
    status_field = Account.current.ticket_fields.find_by_field_type(:default_status)
    status = create_custom_status 
    status = Account.current.ticket_statuses.last
    ct = create_custom_translation(status_field.id,"fr",status_field.name,status_field.label_in_portal,[[status.status_id,status.name]]).translations
    assert_equal status_field.translated_label_in_portal, status_field.label_in_portal
    assert_not_equal Hash[Account.current.ticket_fields.find(5).visible_status_choices][ct["customer_choices"]["choice_#{status.status_id}"]], status.status_id
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

  def test_nested_field_when_custom_translations_enabled_and_user_present
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    User.first.make_current
    User.any_instance.stubs(:language).returns("fr")
    dependent_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
    level1_picklist_value = dependent_field.picklist_values.first
    level2_picklist_value = level1_picklist_value.sub_picklist_values.first
    fields = dependent_field.nested_ticket_fields
    ct = create_custom_translation(dependent_field.id, "fr", dependent_field.name, dependent_field.label_in_portal,[[level1_picklist_value.picklist_id, level1_picklist_value.value], [level1_picklist_value.picklist_id, level2_picklist_value.value]], fields.first).translations
    assert_equal dependent_field.translated_label_in_portal, ct["customer_label"]
    assert_equal fields.first.translated_label_in_portal, ct["customer_label_#{fields.first.level}"]
    level1_choice = dependent_field.translated_nested_choices.first
    level2_choice = level1_choice.last.first
    assert_equal level1_choice[1], ct["choices"]["choice_#{level1_picklist_value.picklist_id}"]
    assert_equal level2_choice[1], ct["choices"]["choice_#{level2_picklist_value.picklist_id}"]
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:supported_languages)
    User.reset_current_user
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

  def test_nested_field_when_custom_translations_enabled_and_user_not_present
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    locale = I18n.locale
    I18n.locale = :fr
    dependent_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
    level1_picklist_value = dependent_field.picklist_values.first
    level2_picklist_value = level1_picklist_value.sub_picklist_values.first
    fields = dependent_field.nested_ticket_fields
    ct = create_custom_translation(dependent_field.id, "fr", dependent_field.name, dependent_field.label_in_portal,[[level1_picklist_value.picklist_id, level1_picklist_value.value], [level1_picklist_value.picklist_id, level2_picklist_value.value]], fields.first).translations
    assert_equal dependent_field.translated_label_in_portal, ct["customer_label"]
    assert_equal fields.first.translated_label_in_portal, ct["customer_label_#{fields.first.level}"]
    level1_choice = dependent_field.translated_nested_choices.first
    level2_choice = level1_choice.last.first
    assert_equal level1_choice[1], ct["choices"]["choice_#{level1_picklist_value.picklist_id}"]
    assert_equal level2_choice[1], ct["choices"]["choice_#{level2_picklist_value.picklist_id}"]
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:supported_languages)
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    I18n.locale = locale
  end

  def test_nested_field_when_custom_translations_enabled_and_user_present_with_different_language
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    User.first.make_current
    User.any_instance.stubs(:language).returns("en")
    dependent_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
    level1_picklist_value = dependent_field.picklist_values.first
    level2_picklist_value = level1_picklist_value.sub_picklist_values.first
    fields = dependent_field.nested_ticket_fields
    ct = create_custom_translation(dependent_field.id, "fr", dependent_field.name, dependent_field.label_in_portal,[[level1_picklist_value.picklist_id, level1_picklist_value.value], [level1_picklist_value.picklist_id, level2_picklist_value.value]], fields.first).translations
    assert_equal dependent_field.translated_label_in_portal, dependent_field.label_in_portal
    assert_equal fields.first.translated_label_in_portal, fields.first.label_in_portal
    level1_choice = dependent_field.translated_nested_choices.first
    level2_choice = level1_choice.last.first
    assert_equal level1_choice[1], level1_picklist_value.value
    assert_equal level2_choice[1], level2_picklist_value.value
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    User.reset_current_user
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

  def test_dropdown_field_when_custom_translations_enabled_and_user_present
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    User.first.make_current
    User.any_instance.stubs(:language).returns("fr")
    dropdown_field = create_custom_field_dropdown
    picklist_value = dropdown_field.picklist_values.first
    ct = create_custom_translation(dropdown_field.id, "fr", dropdown_field.name, dropdown_field.label_in_portal,[[picklist_value.picklist_id, picklist_value.value]]).translations
    assert_equal dropdown_field.translated_label_in_portal, ct["customer_label"]
    assert_equal dropdown_field.html_unescaped_choices(nil,true).first[0], ct["choices"]["choice_#{picklist_value.picklist_id}"]
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:supported_languages)
    User.reset_current_user
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

  def test_dropdown_field_when_custom_translations_enabled_and_user_not_present
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    locale = I18n.locale
    I18n.locale = :fr
    dropdown_field = create_custom_field_dropdown
    picklist_value = dropdown_field.picklist_values.first
    ct = create_custom_translation(dropdown_field.id, "fr", dropdown_field.name, dropdown_field.label_in_portal,[[picklist_value.picklist_id, picklist_value.value]]).translations
    assert_equal dropdown_field.translated_label_in_portal, ct["customer_label"]
    assert_equal dropdown_field.html_unescaped_choices(nil,true).first[0], ct["choices"]["choice_#{picklist_value.picklist_id}"]
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:supported_languages)
    I18n.locale = locale
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_dropdown_field_when_custom_translations_enabled_and_user_present_with_different_language
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    User.first.make_current
    User.any_instance.stubs(:language).returns("en")
    dropdown_field = create_custom_field_dropdown
    picklist_value = dropdown_field.picklist_values.first
    ct = create_custom_translation(dropdown_field.id, "fr", dropdown_field.name, dropdown_field.label_in_portal,[[picklist_value.picklist_id, picklist_value.value]]).translations
    assert_equal dropdown_field.translated_label_in_portal, dropdown_field.label_in_portal
    assert_equal dropdown_field.html_unescaped_choices(nil, true).first[0], picklist_value.value
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    User.reset_current_user
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

  def test_type_field_when_custom_translations_enabled_and_user_present
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    User.first.make_current
    User.any_instance.stubs(:language).returns("fr")
    type_field = @account.ticket_fields.find_by_field_type("default_ticket_type")
    picklist_value = type_field.picklist_values.first
    ct = create_custom_translation(type_field.id, "fr", type_field.name, type_field.label_in_portal,[[picklist_value.picklist_id, picklist_value.value]]).translations
    assert_equal type_field.translated_label_in_portal, ct["customer_label"]
    assert_equal type_field.html_unescaped_choices(nil,true).first[0], ct["choices"]["choice_#{picklist_value.picklist_id}"]
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:supported_languages)
    User.reset_current_user
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

  def test_type_field_when_custom_translations_enabled_and_user_not_present
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_languages).returns(["fr"])
    locale = I18n.locale
    I18n.locale = :fr
    type_field = create_custom_field_dropdown
    picklist_value = type_field.picklist_values.first
    ct = create_custom_translation(type_field.id, "fr", type_field.name, type_field.label_in_portal,[[picklist_value.picklist_id, picklist_value.value]]).translations
    assert_equal type_field.translated_label_in_portal, ct["customer_label"]
    assert_equal type_field.html_unescaped_choices(nil,true).first[0], ct["choices"]["choice_#{picklist_value.picklist_id}"]
  ensure
    Account.any_instance.unstub(:supported_languages)
    Account.any_instance.unstub(:custom_translations_enabled?)
    I18n.locale = locale
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
  end

  def test_type_field_when_custom_translations_enabled_and_user_present_with_different_language
    Helpdesk::PicklistValue.any_instance.stubs(:picklist_id).returns(:id) #once picklist_id migration went live need to remove this stubbing in all places
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    User.first.make_current
    User.any_instance.stubs(:language).returns("en")
    type_field = create_custom_field_dropdown
    picklist_value = type_field.picklist_values.first
    ct = create_custom_translation(type_field.id, "fr", type_field.name, type_field.label_in_portal,[[picklist_value.picklist_id, picklist_value.value]]).translations
    assert_equal type_field.translated_label_in_portal, type_field.label_in_portal
    assert_equal type_field.html_unescaped_choices(nil,true).first[0], picklist_value.value
  ensure
    Account.any_instance.unstub(:custom_translations_enabled?)
    User.reset_current_user
    Helpdesk::PicklistValue.any_instance.unstub(:picklist_id)
    User.any_instance.unstub(:language)
  end

end