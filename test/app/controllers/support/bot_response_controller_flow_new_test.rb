# frozen_string_literal: true

require_relative '../../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Support::BotResponsesControllerFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_filter_without_feature
    user = add_new_user(@account, active: true)
    reset_request_headers
    set_request_auth_headers(user)
    @account.rollback(:bot_email_channel)
    get '/support/bot_responses/filter', url_locale: nil
    assert_response 403
  end

  private

    def old_ui?
      true
    end
end
