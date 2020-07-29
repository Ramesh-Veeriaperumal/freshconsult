require_relative '../../test_helper'
['solutions_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module Ember
  class TicketFieldsControllerTest < ActionController::TestCase
    include TicketFieldsTestHelper
    include SolutionsHelper
    def setup
      super
      before_all
    end

    @@before_all_run = false

    def before_all
      pdt = Product.new(name: 'New Product')
      pdt.account_id = @account.id
      pdt.save
      additional = @account.account_additional_settings
      additional.supported_languages = ['fr']
      additional.save
      @@before_all_run = true
    end

    def wrap_cname(_params)
      remove_wrap_params
      {}
    end

    def test_index_without_group_agent_choices
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      actual_size = @account.ticket_fields.size
      if @account.skill_based_round_robin_enabled?
        actual_size += 1
      end
      assert_equal actual_size, response.count
      agent_field = response.find { |x| x['type'] == 'default_agent' }
      group_field = response.find { |x| x['type'] == 'default_group' }
      refute agent_field['choices'].present?
      refute group_field['choices'].present?
    end

    def test_index_with_default_status_choices
      status = create_custom_status # Just in case custom statuses dont exist
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      status_field = response.find { |x| x['type'] == 'default_status' }
      status_field['choices'].each do |choice|
        # choice[default] should be only true for default statuses
        assert_equal Helpdesk::Ticketfields::TicketStatus::DEFAULT_STATUSES.keys.include?( choice['value']), choice['default']
      end
    end

    def test_index_with_default_skill_choices
      Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
      Account.current.stubs(:skills_trimmed_version_from_cache).returns(create_skill)
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      skill_field = response.find { |x| x['type'] == 'default_skill' }
      assert_equal 2, skill_field['choices'].length
      Account.current.unstub(:skill_based_round_robin_enabled?)
    end

    def test_product_for_product_portal
      pdt = Product.new(name: 'Product A')
      pdt.save
      portal_custom = create_portal(portal_url: 'support.test2.com' , product_id: pdt.id)
      @request.host = portal_custom.portal_url
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      product_choices = response.find { |x| x['type'] == 'default_product'}
      assert_equal Account.current.products.count, product_choices['choices'].count
    end

    def test_product_for_main_portal
      pdt = Product.new(name: 'Product B')
      pdt.save
      portal_default = create_portal
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      product_choices = response.find { |x| x['type'] == 'default_product'}
      assert_equal Account.current.products.count, product_choices['choices'].count
    end

    def test_cache_response_new_product
      #check the memcache here
      pdt = Product.new(name: 'Product B')
      pdt.save
      #check empty in the memchace for key TICKET_FIELDS_FULL:1
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      product_choices = response.find { |x| x['type'] == 'default_product'}
      assert_equal Account.current.products.count, product_choices['choices'].count
      # check for the presence of value even modify it in the memchace for key TICKET_FIELDS_FULL:1
      get :index, controller_params(version: 'private')
      assert_response 200
      response2 = parse_response @response.body
      product_choices = response2.find { |x| x['type'] == 'default_product'}
      assert_equal Account.current.products.count, product_choices['choices'].count
      old_count = Account.current.products.count
      # check for the response is modified value in memcache  for key TICKET_FIELDS_FULL:1

      pdt = Product.new(name: 'Product C')
      pdt.save
      new_count =  Account.current.products.count
      assert new_count > old_count, "New Product added failed"
      #check empty in the memchace for key TICKET_FIELDS_FULL:1
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      product_choices = response.find { |x| x['type'] == 'default_product'}
      choices = product_choices['choices']
      product = choices.detect{ |c| c["label"] == "Product C"}
      assert_equal new_count, choices.count
      assert_not_nil product
      #check the memcache here

    end

    def test_cache_response_new_skill
      #check the memcache here
      @skills_trimmed_version_from_cache = nil
      Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
      Account.current.skills.new(
               :name => 'Skill A',
               :match_type => "all"
        )
      Account.current.save
      
      #check empty in the memchace for key TICKET_FIELDS_FULL:1
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      skill_field = response.find { |x| x['type'] == 'default_skill' }
      assert_equal Account.current.skills.count, skill_field['choices'].length

      # check for the response is modified value in memcache  for key TICKET_FIELDS_FULL:1
      Account.current.skills.new(
               :name => 'Skill B',
               :match_type => "all"
        )
      Account.current.save
      new_count =  Account.current.skills.count
      #check empty in the memchace for key TICKET_FIELDS_FULL:1
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body

      skill_choices = response.find { |x| x['type'] == 'default_skill'}
      choices = skill_choices['choices']
      skill = choices[choices.length-1]
      assert_equal new_count, choices.count
      assert_equal "Skill B", skill["label"]
    end

    def test_index_with_custom_translations_for_status_with_same_user_language
      status_field = Account.current.ticket_fields.find_by_field_type(:default_status)
      stub_params_for_custom_translations('fr')
      status = create_custom_status
      status = Account.current.ticket_statuses.last
      ct = create_custom_translation(status_field.id, 'fr', status_field.name, status_field.label_in_portal, [[status.status_id, status.name]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      status_field = response.find { |field| field['type'] == 'default_status' }
      assert_equal status_field['label'], ct['label']
      assert_equal status_field['label_for_customers'], ct['customer_label']
      choice = status_field['choices'].find { |choices| choices['choice_id'] == status.status_id }
      assert_equal choice['label'], ct['choices']["choice_#{status.status_id}"]
      assert_equal choice['customer_display_name'], ct['customer_choices']["choice_#{status.status_id}"]
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_status_with_different_user_language
      status_field = Account.current.ticket_fields.find_by_field_type(:default_status)
      stub_params_for_custom_translations('en')
      status = create_custom_status
      status = Account.current.ticket_statuses.last
      ct = create_custom_translation(status_field.id, 'fr', status_field.name, status_field.label_in_portal, [[status.status_id, status.name]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      status_response = response.find { |field| field['type'] == 'default_status' }
      assert_equal status_response['label'], status_field.i18n_label
      assert_equal status_response['name'].downcase, status_response['label_for_customers'].downcase
      choice = status_response['choices'].find { |choices| choices['choice_id'] == status.status_id }
      assert_equal status.name.downcase, choice['label'].downcase
      assert_equal choice['customer_display_name'], status.customer_display_name
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_type_with_same_user_language
      type = Account.current.ticket_fields.find_by_field_type(:default_ticket_type)
      type.picklist_values.build(value: Faker::Lorem.characters(10))
      type.save
      db_choice = Account.current.ticket_types_from_cache.last
      stub_params_for_custom_translations('fr')
      ct = create_custom_translation(type.id, 'fr', type.label, type.label_in_portal, [[db_choice.picklist_id, db_choice.value]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      type_field = response.find { |field| field['type'] == 'default_ticket_type' }
      assert_equal type_field['label'], ct['label']
      assert_equal type_field['label_for_customers'], ct['customer_label']
      choice = type_field['choices'].find { |x| x['choice_id'] == db_choice.picklist_id }
      assert_equal choice['label'], ct['choices']["choice_#{db_choice.picklist_id}"]
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_type_with_different_user_language
      type = Account.current.ticket_fields.find_by_field_type(:default_ticket_type)
      type.picklist_values.build(value: Faker::Lorem.characters(10))
      type.save
      db_choice = Account.current.ticket_types_from_cache.last
      stub_params_for_custom_translations('en')
      ct = create_custom_translation(type.id, 'fr', type.label, type.label_in_portal, [[db_choice.picklist_id, db_choice.value]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      type_field = response.find { |field| field['type'] == 'default_ticket_type' }
      assert_equal  type_field['label'], type.i18n_label
      assert_equal 'type', type_field['label_for_customers'].downcase
      choice = type_field['choices'].find { |x| x['choice_id'] == db_choice.picklist_id }
      assert_equal choice['label'], db_choice.value
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_custom_dropdown_with_same_language
      stub_params_for_custom_translations('fr')
      custom_field = create_custom_field_dropdown
      db_choice = custom_field.picklist_values.first
      ct = create_custom_translation(custom_field.id, 'fr', custom_field.label, custom_field.label_in_portal, [[db_choice.picklist_id, db_choice.value]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      dropdown_field = response.find { |field| field['id'] == custom_field.id }
      check_assertion_label_for_custom_translations(dropdown_field, ct, custom_field)
      check_assertions_for_custom_translations(dropdown_field, ct, db_choice)
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_custom_dropdown_with_different_language
      stub_params_for_custom_translations('en')
      custom_field = create_custom_field_dropdown
      db_choice = custom_field.picklist_values.first
      ct = create_custom_translation(custom_field.id, 'fr', custom_field.name, custom_field.label_in_portal, [[db_choice.picklist_id, db_choice.value]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      dropdown_field = response.find { |field| field['id'] == custom_field.id }
      check_assertion_label_for_custom_translations(dropdown_field, nil, custom_field)
      check_assertions_for_custom_translations(dropdown_field, nil, db_choice)
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_dependent_field_level_1_with_same_language
      stub_params_for_custom_translations('fr')
      custom_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
      db_choice = custom_field.picklist_values.first
      ct = create_custom_translation(custom_field.id, 'fr', custom_field.label, custom_field.label_in_portal, [[db_choice.picklist_id, db_choice.value]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      dependent_field = response.find { |field| field['id'] == custom_field.id }
      check_assertion_label_for_custom_translations(dependent_field, ct, custom_field)
      check_assertions_for_custom_translations(dependent_field, ct, db_choice)
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_dependent_field_level_1_with_different_language
      stub_params_for_custom_translations('en')
      custom_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
      db_choice = custom_field.picklist_values.first
      ct = create_custom_translation(custom_field.id, 'fr', custom_field.label, custom_field.label_in_portal, [[db_choice.picklist_id, db_choice.value]]).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      dependent_field = response.find { |field| field['id'] == custom_field.id }
      check_assertion_label_for_custom_translations(dependent_field, nil, custom_field)
      check_assertions_for_custom_translations(dependent_field, nil, db_choice)
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_dependent_field_level_2_with_same_language
      stub_params_for_custom_translations('fr')
      custom_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
      level2_field = custom_field.nested_ticket_fields.find_by_level(2)
      level1_picklist_value = custom_field.picklist_values.first
      level2_picklist_value = level1_picklist_value.sub_picklist_values.first
      ct = create_custom_translation(custom_field.id, 'fr', custom_field.label, custom_field.label_in_portal, [[level2_picklist_value.picklist_id, level2_picklist_value.value]], level2_field).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      dependent_field = response.find { |field| field['id'] == custom_field.id }
      check_assertions_for_custom_translations(dependent_field, ct, level2_picklist_value, 2)
      dependent_field = dependent_field['nested_ticket_fields'].find { |x| x['level'] == 2 }
      check_assertion_label_for_custom_translations(dependent_field, ct, level2_field, 2)
    ensure
      unstub_params_for_custom_translations
    end

    def test_index_with_custom_translations_for_dependent_field_level_2_with_different_language
      stub_params_for_custom_translations('en')
      custom_field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
      level2_field = custom_field.nested_ticket_fields.find_by_level(2)
      level1_picklist_value = custom_field.picklist_values.first
      level2_picklist_value = level1_picklist_value.sub_picklist_values.first
      ct = create_custom_translation(custom_field.id, 'fr', custom_field.label, custom_field.label_in_portal, [[level2_picklist_value.picklist_id, level2_picklist_value.value]], level2_field).translations
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      dependent_field = response.find { |field| field['id'] == custom_field.id }
      check_assertions_for_custom_translations(dependent_field, nil, level2_picklist_value, 2)
      dependent_field = dependent_field['nested_ticket_fields'].find { |x| x['level'] == 2 }
      check_assertion_label_for_custom_translations(dependent_field, nil, level2_field, 2)
    ensure
      unstub_params_for_custom_translations
    end

    def check_assertion_label_for_custom_translations(fields_data_from_api, custom_translation = nil, db_field_data = nil, level = nil)
      label_level = level.to_i > 1 ?  "label_#{level}" : 'label'
      label = custom_translation.nil? ? db_field_data.label : custom_translation[label_level]
      assert_equal fields_data_from_api['label'], label
      label_in_portal = custom_translation.nil? ? db_field_data.label_in_portal : custom_translation['customer_' + label_level]
      assert_equal fields_data_from_api[level.to_i > 1 ? 'label_in_portal' : 'label_for_customers'], label_in_portal
    end

    def check_assertions_for_custom_translations(fields_data_from_api, custom_translation = nil, choice_data = nil, level = nil)
      if choice_data.present?
        choices = fields_data_from_api['choices']
        choice = level.to_i > 1 ? choices.first['choices'].first : choices.find { |choice1| choice1['id'] == choice_data.id }
        choice = choices.first if choice.blank?
        choice_label = custom_translation.nil? ? choice_data.value : custom_translation['choices']["choice_#{choice_data.picklist_id}"]
        assert_equal choice['label'], choice_label
      end
    end

    def stub_params_for_custom_translations(language)
      Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
      User.any_instance.stubs(:language).returns(language)
    end

    def unstub_params_for_custom_translations
      Account.any_instance.unstub(:custom_translations_enabled?)
      User.any_instance.unstub(:language)
    end

    def test_ticket_field_cache_miss_agent_with_account_language
      user_language = Portal.current.try(:language) || Account.current.try(:language)
      stub_account_user_language(nil, user_language) do
        Ember::TicketFieldsController.any_instance.expects(response_cache_data: nil)
        get :index, controller_params(version: 'private')
        assert_response 200
        Ember::TicketFieldsController.any_instance.unstub(:response_cache_data)
      end
    end

    def test_ticket_field_cache_hit_agent_with_account_language
      user_language = Portal.current.try(:language) || Account.current.try(:language)
      stub_account_user_language(nil, user_language) do
        cache_data = { 'test' => 'test' }
        Ember::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        Ember::TicketFieldsController.any_instance.expects(:load_objects).never
        get :index, controller_params(version: 'private')
        assert_response 200
        assert response.body.include?('test')
        Ember::TicketFieldsController.any_instance.unstub(:response_cache_data)
        Ember::TicketFieldsController.any_instance.unstub(:load_objects)
      end
    end

    def test_ticket_field_cache_miss_agent_with_account_supported_language
      acc_supported_language = user_language = 'fr'
      stub_account_user_language(acc_supported_language, user_language) do
        Ember::TicketFieldsController.any_instance.expects(response_cache_data: nil)
        get :index, controller_params(version: 'private')
        assert_response 200
        Ember::TicketFieldsController.any_instance.unstub(:response_cache_data)
      end
    end

    def test_ticket_field_cache_hit_agent_with_account_supported_language
      acc_supported_language = user_language = 'fr'
      stub_account_user_language(acc_supported_language, user_language) do
        cache_data = { 'test' => 'test' }
        Ember::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        Ember::TicketFieldsController.any_instance.expects(:load_objects).never
        get :index, controller_params(version: 'private')
        assert_response 200
        assert response.body.include?('test')
        Ember::TicketFieldsController.any_instance.unstub(:response_cache_data)
        Ember::TicketFieldsController.any_instance.unstub(:load_objects)
      end
    end

    def test_ticket_field_cache_miss_agent_with_non_account_supported_language
      acc_supported_language = 'fr'
      user_language = 'da'
      stub_account_user_language(acc_supported_language, user_language) do
        cache_data = {'test': 'test'}
        Ember::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        get :index, controller_params(version: 'private')
        assert_response 200
        Ember::TicketFieldsController.any_instance.unstub(:response_cache_data)
      end
    end

    def test_all_field_label_has_i18n_label_for_english
      User.any_instance.stubs(:language).returns('en')
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      response.each do |field|
        if field['id'] > 0 # to avoid skill
          db_field = Account.current.ticket_fields.find(field['id']) 
          assert_equal field['label'], db_field.i18n_label
        end
      end
    ensure
      User.any_instance.unstub(:language)
    end

    def test_all_field_label_has_i18n_label_for_french
      User.any_instance.stubs(:language).returns('fr')
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      response.each do |field|
        if field['id'] > 0 # to avoid skill
          db_field = Account.current.ticket_fields.find(field['id'])
          assert_equal field['label'], db_field.i18n_label
        end
      end
    ensure
      User.any_instance.unstub(:language)
    end

    def test_index_with_updated_source_response
      Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      source_field = response.find { |x| x['name'] == 'source' }['choices'].first
      expected_source_fields = %w[id label value position icon_id default deleted]
      assert_equal true, (expected_source_fields - source_field.keys).empty?
    ensure
      Account.current.unstub(:ticket_source_revamp_enabled?)
    end

    private

      def ticket_field_cache_key(language)
        format(MemcacheKeys::TICKET_FIELDS_FULL, account_id: Account.current.id, language_code: language.to_s)
      end

      def stub_account_user_language(acc_supported_language = nil, usr_lang = nil)
        Account.any_instance.stubs(:all_languages).returns([Account.current.language, acc_supported_language]) if acc_supported_language.present?
        User.any_instance.stubs(:language).returns(usr_lang) if usr_lang.present?
        response_cache_key = ticket_field_cache_key(User.current.language) if Account.current.all_languages.include?(User.current.language)
        Ember::TicketFieldsController.any_instance.expects(:response_cache_key).returns(response_cache_key)
        Ember::TicketFieldsController.any_instance.expects(:response_cache_key).returns(response_cache_key)
        yield
        Ember::TicketFieldsController.any_instance.unstub(:response_cache_key)
        Account.any_instance.unstub(:all_languages)
        User.any_instance.unstub(:language)
      end
  end
end
