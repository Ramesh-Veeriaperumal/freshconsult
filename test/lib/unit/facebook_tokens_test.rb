require_relative '../test_helper'
require 'minitest/spec'

class FacebookTokensTest < ActiveSupport::TestCase
  def test_default_app_keys
    stub_tokens(page: false, fallback_account: false, euc_account: false)

    tokens = @facebook_tokens.tokens
    assert_equal(tokens[:app_id], FacebookConfig::APP_ID, 'Default APP ID is not matching')
    assert_equal(tokens[:secret], FacebookConfig::SECRET_KEY, 'Default APP ID is not matching')

    unstub_tokens
  end

  def test_default_page_keys
    stub_tokens(page: true, fallback_account: false, euc_account: false)

    tokens = @facebook_tokens.tokens
    assert_equal(tokens[:app_id], FacebookConfig::PAGE_TAB_APP_ID, 'Default PAGE ID is not matching')
    assert_equal(tokens[:secret], FacebookConfig::PAGE_TAB_SECRET_KEY, 'Default PAGE ID is not matching')

    unstub_tokens
  end

  def test_euc_app_keys
    stub_tokens(page: false, fallback_account: true, euc_account: true)

    tokens = @facebook_tokens.tokens
    assert_equal(tokens[:app_id], FacebookConfig::APP_ID_EUC, 'EUC APP ID is not matching')
    assert_equal(tokens[:secret], FacebookConfig::SECRET_KEY_EUC, 'EUC APP secret is not matching')

    unstub_tokens
  end

  def test_euc_page_keys
    stub_tokens(page: true, fallback_account: true, euc_account: true)

    tokens = @facebook_tokens.tokens
    assert_equal(tokens[:app_id], FacebookConfig::PAGE_TAB_APP_ID_EUC, 'EUC PAGE ID is not matching')
    assert_equal(tokens[:secret], FacebookConfig::PAGE_TAB_SECRET_KEY_EUC, 'EUC PAGE secret is not matching')

    unstub_tokens
  end

  def test_eu_app_keys
    stub_tokens(page: false, fallback_account: true, euc_account: false)

    tokens = @facebook_tokens.tokens
    assert_equal(tokens[:app_id], FacebookConfig::APP_ID_EU, 'EU APP ID is not matching')
    assert_equal(tokens[:secret], FacebookConfig::SECRET_KEY_EU, 'EU APP secret is not matching')

    unstub_tokens
  end

  def test_eu_page_keys
    stub_tokens(page: true, fallback_account: true, euc_account: false)

    tokens = @facebook_tokens.tokens
    assert_equal(tokens[:app_id], FacebookConfig::PAGE_TAB_APP_ID_EU, 'EU PAGE ID is not matching')
    assert_equal(tokens[:secret], FacebookConfig::PAGE_TAB_SECRET_KEY_EU, 'EU PAGE secret is not matching')

    unstub_tokens
  end

  def stub_tokens(options = {})
    @facebook_tokens = Facebook::Tokens.new(options[:page])
    Facebook::Tokens.any_instance.stubs(:fallback_account?).returns(options[:fallback_account])
    Facebook::Tokens.any_instance.stubs(:euc_account?).returns(options[:euc_account])
  end

  def unstub_tokens
    Facebook::Tokens.any_instance.unstub(:fallback_account?)
    Facebook::Tokens.any_instance.unstub(:euc_account?)
  end
end
