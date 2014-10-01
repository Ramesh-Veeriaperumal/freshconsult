require 'spec_helper'

RSpec.configure do |c|
  c.include Import::CustomField
end

RSpec.describe Helpdesk::TicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @group = @account.groups.first
    @account.ticket_fields_with_nested_fields.custom_fields.each &:destroy
    create_filter_supported_custom_fields
    3.times{ prep_a_ticket }
  end

  before(:each) do
    log_in(@agent)
  end

  it "should test all filter test cases" do
    get :filter_options
    filters = assigns(:show_options)
    Wf::TestCase.new(filters).working
  end

  def create_filter_supported_custom_fields
    @invalid_fields = []
    create_field(Wf::FilterFunctionalTestsHelper::NESTED_FIELD.dup, @account)
    create_field(Wf::FilterFunctionalTestsHelper::DROPDOWN.dup, @account)
    if @invalid_fields.present?
      Rails.logger.debug @invalid_fields.inspect
      raise "Error creating ticket fields for Wf::Filter functionality testing
            Invalid Fields #{@invalid_fields.inspect}"
    end
  end

end