require_relative '../../test_helper'

module Admin
  class FreshmarketerControllerTest < ActionController::TestCase
    include FreshmarketerTestHelper
    include TicketHelper

    def wrap_cname(params)
      { freshmarketer: params }
    end

    def test_link_to_new_account
      stub_create_account
      stub_connection
      account_additional_settings = ::Account.current.account_additional_settings
      account_additional_settings.additional_settings ||= {}
      account_additional_settings.additional_settings.delete(:freshmarketer)
      account_additional_settings.save
      put :link, construct_params({ version: 'private' }, link_account_params)
      assert_response 204
    ensure
      unstub_connection
    end

    def test_link_to_new_account_predictive
      stub_create_account
      stub_connection
      account_additional_settings = ::Account.current.account_additional_settings
      account_additional_settings.additional_settings ||= {}
      account_additional_settings.additional_settings.delete(:freshmarketer)
      account_additional_settings.save
      put :link, construct_params({ version: 'private' }, link_account_params)
      assert_response 204
    end

    def test_link_to_existing_account_api_key
      stub_associate_account
      stub_connection
      params_hash = { value: '8236WJDH7H3UFH3483902S', type: 'associate' }
      put :link, construct_params({ version: 'private' }, params_hash)
      assert_response 204
    end

    def test_link_to_existing_account_domain_predictive
      stub_associate_account
      stub_connection
      params_hash = { value: 'xyz.abc.freshmarketer.com', type: 'associate' }
      put :link, construct_params({ version: 'private' }, params_hash)
      assert_response 204
    ensure
      unstub_connection
    end

    def test_unlink_from_account
      put :unlink, controller_params(version: 'private')
      assert_response 204
    end

    def test_enable_integration
      stub_enable_integration
      stub_connection
      save_freshmarketer_hash(
        acc_id: 623_736_473_624,
        auth_token: '37JFU3RY843BF348',
        cdn_script: '',
        app_url: 'http://sr.pre-freshmarketer.io/ab/#/org/7236476347/project/3773/experiment/7373/session/sessions',
        integrate_url: 'http://sr.pre-freshmarketer.io/ab/#/org/7236476347/project/3773/settings/integration'
      )
      put :enable_integration, controller_params(version: 'private')
      assert_response 204
    ensure
      unstub_connection
    end

    def test_disable_integration
      stub_disable_integration
      stub_connection
      save_freshmarketer_hash(
        acc_id: 623_736_473_624,
        auth_token: '37JFU3RY843BF348',
        cdn_script: "<script src='//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/7236476347/4343.js'></script>",
        app_url: 'http://sr.pre-freshmarketer.io/ab/#/org/7236476347/project/3773/experiment/7373/session/sessions',
        integrate_url: 'http://sr.pre-freshmarketer.io/ab/#/org/7236476347/project/3773/settings/integration'
      )
      put :disable_integration, controller_params(version: 'private')
      assert_response 204
    ensure
      unstub_connection
    end

    def test_index
      stub_experiment_details
      stub_connection
      account_additional_settings = ::Account.current.account_additional_settings
      freshmarketer_hash = {
        acc_id: ::Account.current.id,
        auth_token: 'ABC',
        cdn_script: "<script>alert('hi')</script>",
        app_url: 'http://freshmarketer.io',
        integrate_url: 'http://freshmarketer.io/apikey'
      }
      account_additional_settings.additional_settings ||= {}
      account_additional_settings.additional_settings[:freshmarketer] = freshmarketer_hash
      account_additional_settings.save
      get :index, controller_params(version: 'private')
      assert_response 200
      match_json(linked_experiment_pattern(linked: true, name: 'freshmarketer.io'))
    ensure
      unstub_connection
    end

    def test_index_without_linking
      account_additional_settings = ::Account.current.account_additional_settings
      account_additional_settings.additional_settings ||= {}
      account_additional_settings.additional_settings.delete(:freshmarketer)
      account_additional_settings.save
      get :index, controller_params(version: 'private')
      assert_response 200
      match_json(linked_experiment_pattern(linked: false))
    end

    def test_get_recent_sessions
      stub_recent_sessions
      stub_connection
      ticket = create_ticket
      get :sessions, controller_params(version: 'private', id: ticket.display_id, filter: Faker::Internet.email)
      assert_response 200
      response_array = parse_response(response.body)
      response_array.each do |session|
        session.must_match_json_expression(session_pattern(session.symbolize_keys))
      end
    ensure
      unstub_connection
    end

    def test_get_session_info
      stub_session
      stub_connection
      get :session_info, controller_params(version: 'private', session_id: '3433444455.333334')
      assert_response 200
      match_json(session_info_pattern)
    ensure
      unstub_connection
    end

    def test_get_domains
      stub_domains
      stub_connection
      get :domains, controller_params(version: 'private', email_id: 'test@gmail.com')
      assert_response 200
      match_json(get_domains_pattern)
    end

    def test_enable_support_portal
      stub_enable_session_replay
      stub_connection
      put :enable_session_replay, controller_params(version: 'private')
      assert_response 204
    end

    def test_bad_request_error
      stub_bad_request_error_response
      stub_connection
      email = "123@#{@account.full_domain.partition('.').last}"
      params_hash = { value: email, type: 'create' }
      put :link, construct_params({ version: 'private' }, params_hash)
      assert_response 400
    ensure
      unstub_connection
    end

    def test_forbidden_error
      stub_forbidden_error_response
      stub_connection
      put :link, construct_params({ version: 'private' }, link_account_params)
      assert_response 403
    ensure
      unstub_connection
    end

    def test_resource_conflict_error
      stub_resource_conflict_error_response
      stub_connection
      put :link, construct_params({ version: 'private' }, link_account_params)
      assert_response 409
    ensure
      unstub_connection
    end

    def test_internal_server_error
      stub_internal_server_error_response
      stub_connection
      put :link, construct_params({ version: 'private' }, link_account_params)
      assert_response 500
    ensure
      unstub_connection
    end
  end
end
