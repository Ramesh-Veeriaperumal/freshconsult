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

  end
end
