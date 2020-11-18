# frozen_string_literal: true

require_relative '../../../../api/api_test_helper'
require 'webmock/minitest'
['marketplace_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['subscription_test_helper.rb'].each { |file| require "#{Rails.root}/test/models/helpers/#{file}" }

class Admin::Marketplace::ExtensionsControllerFlowTest < ActionDispatch::IntegrationTest
  include MarketplaceHelper
  include SubscriptionTestHelper

  def test_index_extensions_with_sort_by
    index_stub do
      account_wrap do
        get '/admin/marketplace/extensions', version: :private, sort_by: ['latest', 'popular'], type: '1,4,5', format: :json
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal 1, res_body['latest_extensions'].count
    assert_equal 'google_plug', res_body['latest_extensions'][0]['name']
    assert_equal 1, res_body['popular_extensions'].count
    assert_equal 'google_plug', res_body['popular_extensions'][0]['name']
    assert_equal 15, res_body['categories'].count
    assert_equal 'All Apps', res_body['categories'][0]['name']
  end

  def test_index_extensions
    index_stub do
      account_wrap do
        get '/admin/marketplace/extensions', version: :private, type: '1,4,5', format: :json
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal 1, res_body['extensions'].count
    assert_equal 'google_plug', res_body['extensions'][0]['name']
    assert_equal 15, res_body['categories'].count
    assert_equal 'All Apps', res_body['categories'][0]['name']
  end

  def test_index_extensions_with_category_request_error
    Admin::Marketplace::ExtensionsController.any_instance.stubs(:all_categories).returns(request_with_error_response)
    account_wrap do
      get '/admin/marketplace/extensions', version: :private, format: :json, type: '1,4,5'
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:all_categories)
  end

  def test_index_extensions_with_extension_request_error
    index_stub_with_extention_req_error do
      account_wrap do
        get '/admin/marketplace/extensions', version: :private, format: :json, type: '1,4,5'
      end
    end
    assert_response 503
  end

  def test_show_extensions
    show_stub do
      account_wrap do
        get '/admin/marketplace/extensions/1', version: :private, format: :json, type: '1,4,5'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal 'google_plug', res_body['name']
  end

  def test_show_extensions_with_extension_details_request_error
    Admin::Marketplace::ExtensionsController.any_instance.stubs(:extension_details).returns(request_with_error_response)
    account_wrap do
      get '/admin/marketplace/extensions/1', version: :private, format: :json, type: '1,4,5'
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
  end

  def test_show_extensions_with_install_status_request_error
    show_stub_with_install_status_error do
      account_wrap do
        get '/admin/marketplace/extensions/1', version: :private, format: :json
      end
    end
    assert_response 503
  end

  def test_auto_suggest_extensions
    Admin::Marketplace::ExtensionsController.any_instance.stubs(:auto_suggest_mkp_extensions).returns(auto_suggestion)
    account_wrap do
      get '/admin/marketplace/extensions/auto_suggest', version: :private, format: :json, type: '1,4,5', query: 'tre'
    end
    assert_response 200
    res_body = JSON.parse(response.body)[0]
    assert_equal '/admin/marketplace/extensions/1?type=1%2C4%2C5', res_body['show_url']
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:auto_suggest_mkp_extensions)
  end

  def test_auto_suggest_extensions_with_request_error
    Admin::Marketplace::ExtensionsController.any_instance.stubs(:auto_suggest_mkp_extensions).returns(request_with_error_response)
    account_wrap do
      get '/admin/marketplace/extensions/auto_suggest', version: :private, format: :json, type: '1,4,5', query: 'tre'
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:auto_suggest_mkp_extensions)
  end

  def test_search_extensions
    search_stub do
      account_wrap do
        get 'admin/marketplace/extensions/search', version: :private, format: :json, type: '1,4,5', query: 'tre'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)['extensions']
    assert_equal 1, res_body.count
    assert_equal 'google_plug', res_body[0]['name']
  end

  def test_search_extensions_with_category_data_error
    Admin::Marketplace::ExtensionsController.any_instance.stubs(:all_categories).returns(request_with_error_response)
    account_wrap do
      get '/admin/marketplace/extensions/search', version: :private, format: :json, type: '1,4,5'
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:all_categories)
  end

  def test_search_extensions_with_extenstion_data_error
    search_stub_with_extention_req_error do
      account_wrap do
        get '/admin/marketplace/extensions/search', version: :private, format: :json, type: '1,4,5'
      end
    end
    assert_response 503
  end

  def test_custom_apps
    Admin::Marketplace::ExtensionsController.any_instance.stubs(:mkp_custom_apps).returns(custom_apps)
    account_wrap do
      get '/admin/marketplace/extensions/custom_apps', version: :private, format: :json, type: '1,4,5', query: 'tre'
    end
    assert_response 200
    res_body = JSON.parse(response.body)['extensions']
    assert_equal 1, res_body.count
    assert_equal 'google_plug', res_body[0]['name']
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:mkp_custom_apps)
  end

  def test_custom_apps_with_request_error
    Admin::Marketplace::ExtensionsController.any_instance.stubs(:mkp_custom_apps).returns(request_with_error_response)
    account_wrap do
      get '/admin/marketplace/extensions/custom_apps', version: :private, format: :json, type: '1,4,5'
    end
    assert_response 503
  ensure
    Admin::Marketplace::ExtensionsController.any_instance.unstub(:mkp_custom_apps)
  end

  def test_payment_info_when_offline_subscription
    payment_info_stub(true, true, 1) do
      account_wrap do
        get '/admin/marketplace/extensions/1/payment_info', version: :private, format: :json, id: 1, install_url: '/admin/marketplace/installed_extensions/1/1/new_configs?display_name=google_plug&installation_type=install&type=1,4,5'
      end
    end
    assert_response 200
    assert response.body.include?('$10')
  end

  def test_payment_info_when_offline_subscription_with_validation_failed
    payment_info_stub(true, true, 2) do
      account_wrap do
        get '/admin/marketplace/extensions/1/payment_info', version: :private, format: :json, id: 1, install_url: '/admin/marketplace/installed_extensions/1/1/new_configs?display_name=google_plug&installation_type=install&type=1,4,5'
      end
    end
    assert_response 200
    assert response.body.include?(I18n.t('marketplace.payment_contact_support')), " #{response.body} :::::  #{I18n.t('marketplace.payment_contact_support')}"
  end

  def test_payment_info_when_normal_subscription
    Subscription.any_instance.stubs(:card_number).returns('1234')
    payment_info_stub(false, false, 1) do
      account_wrap do
        get '/admin/marketplace/extensions/1/payment_info', version: :private, format: :json, id: 1, install_url: '/admin/marketplace/installed_extensions/1/1/new_configs?display_name=google_plug&installation_type=install&type=1,4,5'
      end
    end
    assert_response 200
    assert response.body.include?('$10')
  ensure
    Subscription.any_instance.unstub(:card_number)
  end

  def test_payment_info_when_normal_subscription_with_validation_failed
    payment_info_stub(false, false, 1) do
      account_wrap do
        get '/admin/marketplace/extensions/1/payment_info', version: :private, format: :json, id: 1, install_url: '/admin/marketplace/installed_extensions/1/1/new_configs?display_name=google_plug&installation_type=install&type=1,4,5'
      end
    end
    assert_response 200
    assert response.body.include?(I18n.t('marketplace.update_payment_info'))
  end

  private

    def old_ui?
      true
    end

    def index_stub
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:all_categories).returns(all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:mkp_extensions).returns(extensions)
      yield
    ensure
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:mkp_extensions)
    end

    def index_stub_with_extention_req_error
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:all_categories).returns(all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:mkp_extensions).returns(request_with_error_response)
      yield
    ensure
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:mkp_extensions)
    end

    def show_stub
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:install_status).returns(install_status)
      yield
    ensure
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:install_status)
    end

    def show_stub_with_install_status_error
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:install_status).returns(request_with_error_response)
      yield
    ensure
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:install_status)
    end

    def search_stub
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:all_categories).returns(all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:search_mkp_extensions).returns(extensions)
      yield
    ensure
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:search_mkp_extensions)
    end

    def search_stub_with_extention_req_error
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:all_categories).returns(all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:search_mkp_extensions).returns(request_with_error_response)
      yield
    ensure
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:all_categories)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:search_mkp_extensions)
    end

    def payment_info_stub(offline_subscription, trial, add_on_id)
      Subscription.any_instance.stubs(:offline_subscription?).returns(offline_subscription)
      result = ChargeBee::Result.new(stub_update_params_with_addons(@account.id, add_on_id))
      Billing::Subscription.any_instance.stubs(:retrieve_subscription).returns(result)
      Subscription.any_instance.stubs(:trial?).returns(trial)
      Admin::Marketplace::ExtensionsController.any_instance.stubs(:extension_details).returns(extension_details_v2_with_addons)
      yield
    ensure
      Subscription.any_instance.unstub(:offline_subscription?)
      Admin::Marketplace::ExtensionsController.any_instance.unstub(:extension_details)
      Billing::Subscription.any_instance.unstub(:retrieve_subscription)
      Subscription.any_instance.unstub(:trial?)
    end
end
