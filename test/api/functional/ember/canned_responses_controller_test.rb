require_relative '../../test_helper'
['canned_responses_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require_relative "#{Rails.root}/lib/helpdesk_access_methods.rb"
require 'webmock/minitest'
WebMock.allow_net_connect!

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


    def test_search_with_feature_disabled
      ca_resp = create_response(
          title: 'when feature disabled',
          content_html: Faker::Lorem.paragraph,
          visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
          folder_id: @ca_folder_personal.id 
        )
      @account.stubs(:personal_canned_response_enabled?).returns(false)
      get :search, controller_params(version: 'private', ticket_id: @@sample_ticket.display_id, search_string: 'when')
      assert_response 200
      @account.unstub(:personal_canned_response_enabled?)
      pattern = []
      pattern << ca_response_search_pattern(ca_resp.id)
      match_json(pattern)
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

    def test_search_with_valid_folder_id
      ca_resp = create_response(
          title: 'Test Canned Response search',
          content_html: Faker::Lorem.paragraph,
          visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
        )
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: stub_response(ca_resp).to_json, status: 200) 
      $redis_others.perform_redis_op("set", "COUNT_ESV2_WRITE_ENABLED", true)
      $redis_others.perform_redis_op("set", "COUNT_ESV2_READ_ENABLED", true) 
      get :search, controller_params(version: 'private', ticket_id: @@sample_ticket.display_id, folder_id: @ca_folder_personal.id, search_string: 'test')
      assert_response 200
      pattern = []
      pattern << ca_response_search_pattern(ca_resp.id)
      match_json(pattern)
    end

    def test_search_validation_with_invalid_folder_id_string
      get :search, controller_params(version: 'private', ticket_id: @@sample_ticket.display_id, folder_id: 'asdl', search_string: 'temp')
      validation_message = {"description":"Validation failed","errors":[{"field":"folder_id","message":"There is no folder_id matching the given asdl","code":"invalid_value"}]}
      
      match_json(validation_message)
      assert_response 400
    end

    def test_search_validation_with_invalid_folder_id_not_in_db
      get :search, controller_params(version: 'private', ticket_id: @@sample_ticket.display_id, folder_id: 100, search_string: 'temp')
      validation_message = {"description":"Validation failed","errors":[{"field":"folder_id","message":"There is no folder_id matching the given 100","code":"invalid_value"}]}
      assert_response 400
      match_json(validation_message)
    end
    
    def test_search_with_valid_folder_id_db
      ca_resp = create_response(
          title: Faker::Lorem.characters(19),
          content_html: Faker::Lorem.paragraph,
          visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
        )
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: nil, status: 200) 
      $redis_others.perform_redis_op("set", "COUNT_ESV2_WRITE_ENABLED", true)
      $redis_others.perform_redis_op("set", "COUNT_ESV2_READ_ENABLED", true)
      get :search, controller_params(version: 'private', search_string: ca_resp.title, ticket_id:  @@sample_ticket.display_id, folder_id: ca_resp.folder_id)
      assert_response 200
      pattern = []
      pattern << ca_response_search_pattern(ca_resp.id)
      match_json(pattern)
    end

    def stub_response(ca_resp)
      {"took"=>1, "timed_out"=>false, "_shards"=>{"total"=>1, "successful"=>1, "failed"=>0}, "hits"=>{"total"=>1, "max_score"=>1.0811163, "hits"=>[{"_index"=>"cannedresponse_alias", "_type"=>"cannedresponse", "_id"=>ca_resp.id, "_score"=>1.0811163, "_routing"=>"1", "_source"=>{"account_id"=>1, "folder_id"=>1, "title"=>"Test Canned Response search", "es_access_type"=>1, "es_group_accesses"=>[], "es_user_accesses"=>[1]}}]}}
    end

  end
end
