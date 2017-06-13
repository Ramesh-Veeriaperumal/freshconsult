require_relative '../test_helper'

class SanitizeFieldsTest < ActiveSupport::TestCase
    include ContactFieldsTestHelper
    include CompanyFieldsTestHelper
    include TicketFieldsTestHelper
    include TicketsTestHelper
    include CompanyTestHelper
    include SanitizeTestHelper

    def setup
        if @account.nil?
            super
        end
    end

    def test_user_fields_sanity
        user = create_user_with_xss
        assert_object user.to_liquid, user
    end

    def test_company_fields_sanity
        company = create_company_with_xss
        assert_object company.to_liquid, company      
    end

    def test_ticket_fields_sanity
        ticket = create_ticket_with_xss
        assert_object ticket.to_liquid, ticket       
    end

end
