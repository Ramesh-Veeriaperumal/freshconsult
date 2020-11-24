# frozen_string_literal: true

require_relative '../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class SupportControllerFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_support_recaptcha
    reset_request_headers
    get '/support/recaptcha', url_locale: nil
    assert_response 200
  end
end
