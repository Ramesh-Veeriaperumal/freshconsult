# frozen_string_literal:true

require_relative '../../api/api_test_helper'

class TwitterRedirectAuthControllerFlowTest < ActionDispatch::IntegrationTest
  include Redis::OthersRedis

  def test_twitter_redirect_auth_complete
    params_hash = {
      state: '8c6289c7979f7eb82646fa2db2b3b3c8',
      oauth_token: 'o5Sp7QAAAAAAEkeSAAABdb1U-aA',
      oauth_verifier: '5W1gGtJrXNfODAO1Ulw1C7MXHhdNAMWU'
    }
    key = "#{Social::Twitter::Constants::COMMON_REDIRECT_REDIS_PREFIX}:#{params_hash[:state]}"
    set_others_redis_key(key, authdone_admin_social_twitters_url, 180)
    get '/twitter/handle/callback', params_hash
    assert_response 302
    assert_redirected_to "#{authdone_admin_social_twitters_url}?oauth_verifier=#{params_hash[:oauth_verifier]}&oauth_token=#{params_hash[:oauth_token]}"
  end

  def test_twitter_redirect_auth_without_state
    params_hash = {
      oauth_token: 'o5Sp7QAAAAAAEkeSAAABdb1U',
      oauth_verifier: '5W1gGtJrXNfODAO1Ulw1C7MXHhdNAMWU'
    }
    get '/twitter/handle/callback', params_hash
    assert_response 302
    assert_redirected_to AppConfig['integrations_url'][Rails.env].to_s
  end

  def test_twitter_redirect_auth_denied
    params_hash = {
      state: '8c6289c7979f7eb82646fa2db2b3b3c8',
      denied: 'hKkh3AAAAAAAEkeSAAABdb1tFco'
    }
    key = "#{Social::Twitter::Constants::COMMON_REDIRECT_REDIS_PREFIX}:#{params_hash[:state]}"
    set_others_redis_key(key, authdone_admin_social_twitters_url, 180)
    get '/twitter/handle/callback', params_hash
    assert_response 302
    assert_redirected_to authdone_admin_social_twitters_url
  end
end
