require_relative '../test_helper'

class SanitizeFieldsTest < ActiveSupport::TestCase
	include ContactFieldsTestHelper
	include CompanyFieldsTestHelper
	include TicketFieldsTestHelper
	include TicketsTestHelper
	include CompanyTestHelper
	include SanitizeTestHelper
	include Sanitize::FieldValues


	def setup
		if @account.nil?
			super
			@company = create_company_with_xss						#build company
			params = {}
			params[:customer_id] = @company.id

			@contact = create_user_with_xss params					#build contact
			@agent = add_agent @account								#build agent
			
			params[:requester_id] = @contact.id   					#build ticket with normal requester.
			@ticket_from_contact = create_ticket_with_xss params
			params = {}

			params[:requester_id] = @agent.id 						#build ticket with agent as requester.
			@ticket_from_agent = create_ticket_with_xss params
		end
	end

	test "xss fields sanitization in company" do
		assert_object @company
	end


	test "xss fields sanitization in requester" do
		assert_object @contact
		assert_object @agent
	end

	test "xss fields sanitization in ticket" do
		assert_object @ticket_from_contact
		assert_object @ticket_from_contact.requester
		assert_object @ticket_from_agent
		assert_object @ticket_from_agent.requester
	end
end
