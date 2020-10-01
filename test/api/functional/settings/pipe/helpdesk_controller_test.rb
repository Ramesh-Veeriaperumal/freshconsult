require_relative '../../../test_helper'

module Settings
  class Pipe::HelpdeskControllerTest < ActionController::TestCase
    include Redis::RedisKeys
    include Redis::DisplayIdRedis

    def wrap_cname(params)
      { api_helpdesk: params }
    end

    def account_api_limit_key
      ACCOUNT_API_LIMIT % { account_id: Account.current.id }
    end

    def get_account_api_limit
      $rate_limit.perform_redis_op("get", account_api_limit_key)
    end
    
    def set_default_limit
      $rate_limit.perform_redis_op("del", account_api_limit_key)
    end
    def set_account_api_limit(value)
      $rate_limit.perform_redis_op("set", account_api_limit_key, value)
    end

    #Tests Start

    def test_toggle_email_valid_enable
      Account.current.disable_setting(:disable_emails)
      put :toggle_email, construct_params({ version: 'pipe', disabled: true})
      assert Account.current.disable_emails_enabled?
      Account.current.disable_setting(:disable_emails)
    end

    def test_toggle_email_valid_disable
      Account.current.enable_setting(:disable_emails)
      put :toggle_email, construct_params({ version: 'pipe', disabled: false})
      assert !Account.current.disable_emails_enabled?
    end

    def test_toggle_email_invalid_enable
      put :toggle_email, construct_params({ version: 'pipe', disabledX: true})
      assert_response 400
      put :toggle_email, construct_params({ version: 'pipe', disabled: "true"})
      assert_response 400
      put :toggle_email, construct_params({ version: 'pipe', disabledX: 123})
      assert_response 400
    end

    def test_toggle_fast_ticket_creation_enable
      Account.current.features.redis_display_id.destroy if Account.current.features?(:redis_display_id)
      put :toggle_fast_ticket_creation, construct_params({ version: 'pipe', disabled: false})
      assert Account.current.features?(:redis_display_id)
      key = TICKET_DISPLAY_ID % { :account_id => Account.current.id }
      assert_equal(get_display_id_redis_key(key), "#{TicketConstants::TICKET_START_DISPLAY_ID}")
      Account.current.features.redis_display_id.destroy
    end  

    def test_toggle_fast_ticket_creation_disable
      Account.current.features.redis_display_id.create if Account.current.features?(:redis_display_id)
      put :toggle_fast_ticket_creation, construct_params({ version: 'pipe', disabled: true})
      assert !Account.current.features?(:redis_display_id)
      Account.current.features.redis_display_id.destroy
    end

    def test_toggle_fast_ticket_creation_invalid_param
      put :toggle_fast_ticket_creation, construct_params({ version: 'pipe', disabledX: true})
      assert_response 400
      put :toggle_fast_ticket_creation, construct_params({ version: 'pipe', disabled: "true"})
      assert_response 400
      put :toggle_fast_ticket_creation, construct_params({ version: 'pipe', disabledX: 123})
      assert_response 400
    end

    def test_change_api_v2_limit_non_null
      set_default_limit
      put :change_api_v2_limit, construct_params({ version: 'pipe', limit: 20000})
      expected = {
        old_limit: nil,
        limit: 20000
      }
      match_json(expected)
      assert_equal(get_account_api_limit.to_i, 20000)
    end

    def test_change_api_v2_limit_revert
      set_account_api_limit(20000)
      put :change_api_v2_limit, construct_params({ version: 'pipe', limit: nil})
      expected = {
        old_limit: 20000,
        limit: nil
      }
      match_json(expected)
      assert_equal(get_account_api_limit, nil)
      set_default_limit
    end

    def test_change_api_v2_limit_max
      set_default_limit
      put :change_api_v2_limit, construct_params(version: 'pipe', limit: 130_000)
      expected = {
        old_limit: nil,
        limit: ::Pipe::HelpdeskConstants::MAX_API_LIMIT
      }
      match_json(expected)
      assert_equal(get_account_api_limit, "#{::Pipe::HelpdeskConstants::MAX_API_LIMIT}")
    end

    def test_change_api_v2_limit_invalid_param
      put :change_api_v2_limit, construct_params({ version: 'pipe', limitX: 30000})
      assert_response 400
      put :change_api_v2_limit, construct_params({ version: 'pipe', limit: "30000"})
      assert_response 400
      put :change_api_v2_limit, construct_params({ version: 'pipe', limit: true})
      assert_response 400
      put :change_api_v2_limit, construct_params({ version: 'pipe', limasd: true})
      assert_response 400
    end
  end
end
