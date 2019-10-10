require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class MiddlewareTest < ActionView::TestCase
  def test_locale_reset
    Account.first.make_current
    ::Sidekiq::Testing.server_middleware do |chain|
      chain.add ::Middleware::Sidekiq::Server::UnsetThread
    end

    I18n.locale = 'fr'
    LaunchPartyActionWorker.perform_async({account_id: 1, features: []})
    LaunchPartyActionWorker.drain
    assert_equal I18n.default_locale, I18n.locale
  end
end
