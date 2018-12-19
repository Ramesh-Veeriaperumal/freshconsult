require_relative '../../../test_helper'

module Ember
  module Dashboard
    class QuestsControllerTest < ActionController::TestCase
      include DashboardTestHelper

      def test_index_without_gamification_feature
        disable_gamification
        get :index, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Gamification'))
      ensure
        Account.current.add_feature(:gamification)
      end

      def test_index
        enable_gamification do
          get :index, controller_params(version: 'private')
          assert_response 200
          match_json(quests_pattern(Account.current.quests))
        end
      end

      def test_index_with_invalid_field
        enable_gamification do
          get :index, controller_params(version: 'private', test: 'test')
          assert_response 400
          match_json([bad_request_error_pattern('test', :invalid_field)])
        end
      end

      def test_index_with_invalid_value_for_filter
        enable_gamification do
          get :index, controller_params(version: 'private', filter: 'test')
          assert_response 400
          match_json([bad_request_error_pattern(:filter, :not_included, list: QuestConstants::FILTERS)])
        end
      end

      def test_index_with_unachieved_filter
        enable_gamification do
          quest = Account.current.quests.first
          achieved_quest = quest.achieved_quests.build(user_id: User.current.id)
          achieved_quest.save
          get :index, controller_params(version: 'private', filter: 'unachieved')
          assert_response 200
          match_json(quests_pattern(Account.current.quests.available(User.current)))
          assert_not_includes(response.body, quest_pattern(quest).to_json)
        end
      end
    end
  end
end
