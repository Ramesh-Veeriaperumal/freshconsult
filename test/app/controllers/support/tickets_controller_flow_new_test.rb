# frozen_string_literal: true

require_relative '../../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Support::TicketsControllerFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_index_for_suspended_account
    user = add_new_user(@account, active: true)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:active?).returns(false)
    last_updated = @account.subscription.updated_at
    @account.subscription.updated_at = 2.days.ago
    @account.subscription.save
    get 'support/tickets', url_locale: nil
    assert_equal I18n.t('flash.general.portal_blocked'), flash[:notice]
    assert_response 302
  ensure
    Account.any_instance.unstub(:active?)
    @account.make_current
    @account.subscription.updated_at = last_updated
    @account.subscription.save
  end

  def old_ui?
    true
  end
end
