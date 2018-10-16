require_relative '../../../test_helper'

class Ember::Search::AutocompleteControllerTest < ActionController::TestCase
    include PrivilegesHelper
    ES_DELAY_TIME = 5

    ########################
    # Requester test cases # 
    ########################
    def test_requester_with_complete_name
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.name})
      assert_response 200
      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_name_auto_complete_disabled
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      disable_auto_complete
      post :requesters, construct_params({term: user.name})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_empty res_body
      assert_response 200

      rollback_auto_complete
    end

    def test_requester_with_name_auto_complete_off_view_contacts_privilege_on
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      @account.launch(:auto_complete_off)
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.name})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      @account.rollback(:auto_complete_off)
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_email_auto_complete_disabled
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      disable_auto_complete
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.email})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      rollback_auto_complete
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_partial_email_auto_complete_disabled
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      disable_auto_complete
      
      post :requesters, construct_params({term: user.email.split('@').first})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_empty res_body
      assert_response 200

      rollback_auto_complete
    end

    def test_requester_with_phone_number_auto_complete_disabled
      user = add_new_user_without_email(@account)
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
      
      disable_auto_complete

      post :requesters, construct_params({term: user.phone})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_empty res_body
      assert_response 200

      rollback_auto_complete
    end

    def test_requester_with_partial_name
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.name[0..5]})
      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_complete_email
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      
      post :requesters, construct_params({term: user.email})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      SearchService::QueryHandler.any_instance.unstub(:query_results)

    end

    def test_requester_with_partial_email
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      
      post :requesters, construct_params({term: user.email.split('@').first})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_email_domain
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      
      post :requesters, construct_params({term: user.email.split('@').last})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_phone_number
      user = add_new_user_without_email(@account)
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      
      post :requesters, construct_params({term: user.phone})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      SearchService::QueryHandler.any_instance.unstub(:query_results)

    end

    def test_requester_with_phone_number_auto_complete_off_view_contacts_privilege_on
      user = add_new_user_without_email(@account)
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      @account.launch(:auto_complete_off)
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.phone})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      @account.rollback(:auto_complete_off)
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_email_auto_complete_off_view_contacts_privilege_on
      user = add_new_user_without_email(@account)
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      @account.launch(:auto_complete_off)
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.email})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      @account.rollback(:auto_complete_off)
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_partial_email_auto_complete_off_view_contacts_privilege_on
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      @account.launch(:auto_complete_off)
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.email.split('@').first})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      @account.rollback(:auto_complete_off)
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_partial_name_auto_complete_off_view_contacts_privilege_on
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      @account.launch(:auto_complete_off)
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], { total_entries: 1}))
      post :requesters, construct_params({term: user.name[0..5]})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_includes res_body, user.id
      assert_response 200
      @account.rollback(:auto_complete_off)
      SearchService::QueryHandler.any_instance.unstub(:query_results)
    end

    def test_requester_with_partial_name_auto_complete_disabled
      user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
      sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

      disable_auto_complete
      
      post :requesters, construct_params({term: user.name[0..5]})

      res_body = parse_response(@response.body).map { |item| item['id'] }
      assert_empty res_body
      assert_response 200

      rollback_auto_complete
    end



    private 

      def disable_auto_complete
        remove_privilege(User.current,:view_contacts)
        @account.launch(:auto_complete_off)
      end

      def rollback_auto_complete
        add_privilege(User.current, :view_contacts)
        @account.rollback(:auto_complete_off)
      end
    
  end
