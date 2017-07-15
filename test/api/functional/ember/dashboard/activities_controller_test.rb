require_relative '../../../test_helper'
module Ember
  module Dashboard
    class ActivitiesControllerTest < ActionController::TestCase
      include DashboardTestHelper
      include DashboardActivitiesTestHelper
      include TicketsTestHelper
      include TicketActivitiesTestHelper
      include PrivilegesHelper
      include UsersTestHelper
      include ForumsTestHelper
      include SolutionsTestHelper

      PAGE_LIMIT = 30
      PER_PAGE = 20
      def test_activities_create_ticket
        requester, ticket = create_new_ticket
        action_type = 'new_ticket'
        expected = get_activity_pattern(last_activity, requester,action_type)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
        clean_up(ticket, requester)
      end

      def test_activities_add_note
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        note = create_private_note(ticket)
        action_type = 'note'
        action_content = {'note_id'=>note.id}
        expected = get_activity_pattern(last_activity, @agent,action_type,action_content)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
        clean_up(@agent, ticket, requester)
      end

      def test_activities_add_forum_category
        forum_category = create_test_category
        action_type = 'new_forum_category'
        action_content = {}
        expected = get_activity_pattern(last_activity, User.current,action_type,action_content)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
        clean_up(forum_category)
      end

      def test_activities_add_forum
        forum_category, forum = create_new_forum
        action_type = 'new_forum'
        action_content = {'category_name'=>forum_category.name}
        expected = get_activity_pattern(last_activity, User.current,action_type,action_content)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
        clean_up(forum, forum_category)
      end

      def test_activities_add_topic
        forum_category, forum = create_new_forum
        topic = create_test_topic(forum, User.current)
        action_type = 'new_topic'
        action_content = {'forum_name'=>forum.name}
        expected = get_activity_pattern(last_activity, User.current,action_type,action_content)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
        clean_up(topic, forum, forum_category)
      end

      def test_activities_with_no_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        tickets = []
        PAGE_LIMIT.times do
          tickets << create_ticket(:requester_id => requester.id)
        end
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(PAGE_LIMIT, JSON.parse(@response.body).count)
        tickets.each do |ticket|
          ticket.destroy
        end
        clean_up(@agent, requester)
      end

      def test_activities_with_page_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        target_activity = @account.activities.last
        tickets = []
        PAGE_LIMIT.times do
          tickets << create_ticket(:requester_id => requester.id)
        end
        get :index, controller_params({version: 'private', page: 2})
        assert_response 200
        assert_equal(target_activity.id, JSON.parse(@response.body)[0]["id"])
        tickets.each do |ticket|
          ticket.destroy
        end
        clean_up(@agent, requester)
      end

      def test_activities_with_per_page_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        tickets = []
        25.times do
          tickets << create_ticket(:requester_id => requester.id)
        end
        get :index, controller_params({version: 'private', per_page: PER_PAGE})
        assert_response 200
        assert_equal(PER_PAGE, JSON.parse(@response.body).count)
        tickets.each do |ticket|
          ticket.destroy
        end
        clean_up(@agent, requester)
      end

      def test_activities_with_page_and_per_page_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        tickets = []
        60.times do
          tickets << create_ticket(:requester_id => requester.id)
        end
        get :index, controller_params({version: 'private', page: 2, per_page: PER_PAGE})
        assert_response 200
        assert_equal(PER_PAGE, JSON.parse(@response.body).count)
        tickets.each do |ticket|
          ticket.destroy
        end
        clean_up(@agent, requester)
      end

      def test_activities_with_before_id
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        action_type = 'new_ticket'
        action_content = {}
        expected = get_activity_pattern(last_activity, requester,action_type,action_content)
        note = create_private_note(ticket)
        get :index, controller_params({version: 'private', before_id: last_activity.id})
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
        clean_up(@agent, ticket, requester)
      end

      def test_activities_with_page_and_before_id
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        PAGE_LIMIT.times do
          note = create_private_note(ticket)
        end
        action_type = 'new_ticket'
        action_content = {}
        get :index, controller_params({version: 'private', page: 1, before_id: last_activity.id})
        assert_response 200
        assert_equal(PAGE_LIMIT, JSON.parse(@response.body).count)
        clean_up(@agent, ticket, requester)
      end

      def test_activities_with_page_per_page_and_before_id
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        PAGE_LIMIT.times do
          note = create_private_note(ticket)
        end
        action_type = 'new_ticket'
        action_content = {}
        get :index, controller_params({version: 'private', page: 1, per_page: PER_PAGE, before_id: last_activity.id})
        assert_response 200
        assert_equal(PER_PAGE, JSON.parse(@response.body).count)
        clean_up(@agent, ticket, requester)
      end

      def test_activities_with_since_id
        requester, ticket = create_new_ticket
        since_id = last_activity.id
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        notes = []
        activities = []
        3.times do
          notes << create_private_note(ticket)
          activities << @account.activities.last
        end
        action_type = 'note'
        action_content = {"note_id"=>notes[0].id}
        expected = get_activity_pattern(activities[0], @agent,action_type,action_content)
        get :index, controller_params({version: 'private', since_id: since_id})
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[2])
        clean_up(@agent, ticket, requester)
      end

      def test_activities_with_since_id_and_before_id
        get :index, controller_params({version: 'private', since_id: 10, before_id: 10})
        expected = {
          description: 'Validation failed',
          errors: [
            {
              field: 'since_id_or_before_id',
              message: 'Specify since_id or before_id, not both',
              code: 'invalid_value'
            }
          ]
        }
        match_json(expected)
        assert_response 400
      end

      def test_activities_with_page_that_does_not_exist
        get :index, controller_params({version: 'private', page: 200})
        assert_response 200
        assert_equal(0, JSON.parse(@response.body).count)
      end

      def test_activities_without_access_to_dashboard
        User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
        get :index, construct_params(version: 'private')
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_activities_with_invalid_params
        get :index, construct_params({version: 'private', invalid: 'invalid_params'})
        assert_response 400
      end

      private

      def create_new_ticket
        requester = add_new_user(@account)
        ticket = create_ticket(:requester_id => requester.id)
        [requester, ticket]
      end

      def create_new_forum
        forum_category = create_test_category
        forum = create_test_forum(forum_category)
        [forum_category, forum]
      end

      def clean_up(*args)
        args.each do |arg|
          arg.destroy
        end
      end

      def last_activity
        @account.activities.last
      end
    end
  end
end
