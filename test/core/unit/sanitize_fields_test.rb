require_relative '../test_helper'

class SanitizeFieldsTest < ActiveSupport::TestCase
    include ContactFieldsTestHelper
    include CompanyFieldsTestHelper
    include CoreTicketFieldsTestHelper
    include CoreTicketsTestHelper
    include CompanyTestHelper
    include SanitizeTestHelper

    def setup
        if @account.nil?
            super
            @ticket = create_ticket_with_xss
            @ticket.escape_liquid_attributes = true
            @user = create_user_with_xss
            @user.escape_liquid_attributes = true
            @company = create_company_with_xss
            @company.escape_liquid_attributes = true            
        end
    end

    def test_ticket_fields_sanity
        ticket_liquid = set_context_and_fetch_liquid_object(@ticket)
        assert_escape_for_text_fields ticket_liquid, @ticket
    end


    def test_user_fields_sanity
        user_liquid = set_context_and_fetch_liquid_object(@user)
        assert_escape_for_text_fields user_liquid, @user
    end

    def test_company_fields_sanity        
        company_liquid = set_context_and_fetch_liquid_object(@company)
        assert_escape_for_text_fields company_liquid, @company      
    end

    def test_ticket_associations_sanity
        company = @ticket.company = @company
        company_liquid = set_context_and_fetch_liquid_object(company)
        requester = @ticket.requester = @user
        requester_liquid = set_context_and_fetch_liquid_object(requester)
        assert_escape_for_text_fields company_liquid, company
        assert_escape_for_text_fields requester_liquid, requester
    end

    def test_requester_associations_sanity
        company = @user.company = @company
        company_liquid = set_context_and_fetch_liquid_object(company)
        assert_escape_for_text_fields company_liquid, company
    end

    def test_double_escape
        ticket_liquid = set_context_and_fetch_liquid_object(@ticket)
        assert_equal h(ticket_liquid.subject), ticket_liquid.subject
        fields(@ticket).each do |field|
          key = field.gsub("_#{@account.id}", '').to_sym
          assert_equal h(ticket_liquid[key]), ticket_liquid[key].to_s
        end
    end

end