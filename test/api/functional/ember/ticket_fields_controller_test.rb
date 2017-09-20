require_relative '../../test_helper'

module Ember
  class TicketFieldsControllerTest < ActionController::TestCase
    include TicketFieldsTestHelper

    def setup
      super
      before_all
    end

    @@before_all_run = false

    def before_all
      pdt = Product.new(name: 'New Product')
      pdt.account_id = @account.id
      pdt.save
      @@before_all_run = true
    end

    def wrap_cname(_params)
      remove_wrap_params
      {}
    end

    def test_index_without_group_agent_choices
      get :index, controller_params(version: 'private')
      assert_response 200
      response = parse_response @response.body
      assert_equal @account.ticket_fields.size, response.count
      agent_field = response.find { |x| x['type'] == 'default_agent' }
      group_field = response.find { |x| x['type'] == 'default_group' }
      refute agent_field['choices'].present?
      refute group_field['choices'].present?
    end

    def test_index_with_default_status_choices
      status = create_custom_status # Just in case custom statuses dont exist
      get :index, controller_params(version: 'private')
      assert_response 200   
      response = parse_response @response.body
      status_field = response.find { |x| x['type'] == 'default_status' }
      status_field['choices'].each do |choice|
        # choice[default] should be only true for default statuses
        assert_equal Helpdesk::Ticketfields::TicketStatus::DEFAULT_STATUSES.keys.include?( choice['value']), choice['default']
      end
    end
  end
end