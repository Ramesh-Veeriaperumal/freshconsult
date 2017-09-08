require_relative '../test_helper'
require_relative '../custom_assertions/account_creation_assertions.rb'

class AccountsControllerTest < ActionController::TestCase
	include AccountCreationAssertions

	def setup
		super
	end

	def test_without_background_fixtures_turned_on
		disable_background_fixtures
		create_test_account
		assert_fixtures_data
	end

	def test_with_background_fixtures_turned_on
		enable_background_fixtures
		Sidekiq::Testing.inline! do
			create_test_account
		end
		assert_fixtures_data
	end
end