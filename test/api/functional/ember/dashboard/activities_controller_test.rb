require_relative '../../../test_helper'
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module Ember
  module Dashboard
    class ActivitiesControllerTest < ActionController::TestCase
      include DashboardTestHelper
      include DashboardActivitiesTestHelper
      include ApiTicketsTestHelper
      include TicketActivitiesTestHelper
      include PrivilegesHelper
      include UsersTestHelper
      include ForumsTestHelper
      include SolutionsTestHelper
      include SocialTicketsCreationHelper
      include ActivityConstants

      PAGE_LIMIT = 30
      PER_PAGE   = 20
      @@before_all_run = false

      def setup
        super
        @account.reload
        $redis_others.perform_redis_op("set", "ARTICLE_SPAM_REGEX","(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)")
        $redis_others.perform_redis_op("set", "PHONE_NUMBER_SPAM_REGEX", "(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436")
        $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ')

        before_all
      end

      def before_all
        return if @@before_all_run
        create_n_tickets(PAGE_LIMIT*2)
        @@before_all_run = true
      end

      def test_per_page_params_greater_than_max_limit
        stub_const(DashboardConstants, 'MAX_PAGE_LIMIT', 50) do
          get :index, controller_params(version: 'private', per_page: 60)
          assert_equal @controller.instance_variable_get(:@per_page), 50
        end
      end

      def test_per_page_params_lesser_than_min_limit
        get :index, controller_params(version: 'private', per_page: 10)
        assert_equal @controller.instance_variable_get(:@per_page), DashboardConstants::MIN_PAGE_LIMIT
      end

      def test_per_page_params_within_limit
        get :index, controller_params(version: 'private', per_page: 40)
        assert_equal @controller.instance_variable_get(:@per_page), 40
      end

      def test_run_time_error
        Helpdesk::Activity.stubs(:freshest).raises(RuntimeError)
        get :index, controller_params(version: 'private', since_id: 1, per_page: 40)
        Helpdesk::Activity.unstub(:freshest)
        assert_response 500
      end

      def test_activities_create_ticket
        requester, ticket = create_new_ticket
        action_type = 'new_ticket'
        expected = get_activity_pattern(last_activity, requester,action_type)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
      end

      def test_activities_add_note
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        note = create_private_note(ticket)
        action_type = 'note'
        action_content = { 'note' => { 'id' => note.id, 'source' => nil, 'incoming' => nil } }
        expected = get_activity_pattern(last_activity, @agent,action_type,action_content)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
      end

      # def test_activities_add_forum_category
      #   forum_category = create_test_category
      #   action_type = 'new_forum_category'
      #   action_content = {}
      #   expected = get_activity_pattern(last_activity, User.current,action_type,action_content)
      #   get :index, controller_params(version: 'private')
      #   assert_response 200
      #   assert_equal(expected, JSON.parse(@response.body)[0])
      # end

      # def test_activities_add_forum
      #   forum_category, forum = create_new_forum
      #   action_type = 'new_forum'
      #   action_content = {'category_name'=>forum_category.name}
      #   expected = get_activity_pattern(last_activity, User.current,action_type,action_content)
      #   get :index, controller_params(version: 'private')
      #   assert_response 200
      #   assert_equal(expected, JSON.parse(@response.body)[0])
      # end

      # def test_activities_add_topic
      #   forum_category, forum = create_new_forum
      #   topic = create_test_topic(forum, User.current)
      #   action_type = 'new_topic'
      #   action_content = {'forum_name'=>forum.name}
      #   expected = get_activity_pattern(last_activity, User.current,action_type,action_content)
      #   get :index, controller_params(version: 'private')
      #   assert_response 200
      #   assert_equal(expected, JSON.parse(@response.body)[0])
      # end

      def test_activities_with_no_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        get :index, controller_params(version: 'private')
        assert_response 200
        assert_equal(PAGE_LIMIT, JSON.parse(@response.body).count)
      end

      def test_activities_with_page_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        target_activity = @account.activities.include_modules(NOTABLE_TYPES).last(PAGE_LIMIT + 1).first
        get :index, controller_params({version: 'private', page: 2})
        assert_response 200
        assert_equal(target_activity.id, JSON.parse(@response.body)[0]['id'])
      end

      def test_activities_with_per_page_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        get :index, controller_params({version: 'private', per_page: PER_PAGE})
        assert_response 200
        assert_equal(PER_PAGE, JSON.parse(@response.body).count)
      end

      def test_activities_with_page_and_per_page_params
        requester = add_new_user(@account)
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        get :index, controller_params({version: 'private', page: 2, per_page: PER_PAGE})
        assert_response 200
        assert_equal(PER_PAGE, JSON.parse(@response.body).count)
      end

      def test_activities_with_before_id
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        action_type = 'new_ticket'
        action_content = {}
        expected = get_activity_pattern(last_activity, requester, action_type, action_content)
        note = create_private_note(ticket)
        get :index, controller_params({version: 'private', before_id: last_activity.id})
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
      end

      def test_activities_with_page_and_before_id
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        get :index, controller_params({version: 'private', page: 1, before_id: last_activity.id})
        assert_response 200
        assert_equal(PAGE_LIMIT, JSON.parse(@response.body).count)
      end

      def test_activities_with_page_per_page_and_before_id
        requester, ticket = create_new_ticket
        @agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        get :index, controller_params({version: 'private', page: 1, per_page: PER_PAGE, before_id: last_activity.id})
        assert_response 200
        assert_equal(PER_PAGE, JSON.parse(@response.body).count)
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
        action_content = { 'note' => { 'id' => notes[0].id, 'source' => nil, 'incoming' => nil } }
        expected = get_activity_pattern(activities[0], @agent, action_type, action_content)
        get :index, controller_params({version: 'private', since_id: since_id})
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[2])
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

      def test_activities_with_no_user
        requester, ticket = create_new_ticket
        sidekiq_inline {
        requester.delete_forever!
        }
        expected = get_activity_pattern(last_activity, requester,"new_ticket")
        get :index, controller_params({version: 'private'})
        assert_response 200
        assert_equal(expected, JSON.parse(@response.body)[0])
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

      def last_activity
        @account.activities.last
      end
    end
  end
end
