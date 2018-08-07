require_relative '../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require_relative "#{Rails.root}/lib/helpdesk_access_methods.rb"

module Ember
  class CannedResponsesControllerTest < ActionController::TestCase
    include GroupHelper
    include CannedResponsesHelper
    include CannedResponsesTestHelper
    include CannedResponseFoldersTestHelper
    include HelpdeskAccessMethods
    include AgentHelper
    include TicketHelper
    include AttachmentsTestHelper

    def setup
      super
      before_all
    end

    @@sample_ticket  = nil
    @@before_all_run = false
    @@ca_folder_all  = nil

    def before_all      
      @account = Account.first.make_current      
      @agent = get_admin
      @ca_folder_personal = @account.canned_response_folders.personal_folder.first

      return if @before_all_run

      @@ca_folder_all = create_cr_folder(name: Faker::Name.name)
      @@sample_ticket ||= create_ticket
      @account.subscription.update_column(:state, 'active')

      @@before_all_run = true
    end
    
    def test_search_with_invalid_ticket_id
      invalid_id = create_ticket.display_id + 20
      get :search, controller_params(version: 'private', ticket_id: invalid_id, search_string: 'Test')
      assert_response 404
    end

    def test_search_without_search_string
      get :search, controller_params(version: 'private', ticket_id: @@sample_ticket.display_id)
      assert_response 400
      match_json([bad_request_error_pattern('search_string', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
    end

    def test_search
      ca_responses = Array.new(5) do
        create_response(
          title: 'Test Canned Response search',
          content_html: Faker::Lorem.paragraph,
          visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
        )
      end
      ids_passed = ca_responses.collect(&:id)
      get :search, controller_params(version: 'private', ticket_id: @@sample_ticket.display_id, search_string: 'Canned Response')
      assert_response 200
      pattern = []
      ca_responses.first(5).each do |ca|
        pattern << ca_response_search_pattern(ca.id)
      end
      get :index, controller_params(version: 'private', ids: ids_passed.join(',') )
      match_json(pattern)
    end
  end
end
