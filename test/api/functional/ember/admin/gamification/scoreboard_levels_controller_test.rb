require_relative '../../../../test_helper'

module Ember
  module Admin
    module Gamification
      class ScoreboardLevelsControllerTest < ActionController::TestCase
        include ScoreboardLevelHelper

        def test_index_without_admin_tasks_privilege
          User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
          get :index, controller_params(version: 'private')
          assert_response 200
          pattern = []
          Account.current.scoreboard_levels.each do |sb_level|
            pattern << scoreboard_level_pattern(sb_level, false)
          end
          match_json(pattern)
        ensure
          User.any_instance.unstub(:privilege?)
        end

        def test_index_with_admin_tasks_privilege
          User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
          User.any_instance.stubs(:privilege?).with(:manage_users).returns(true)
          get :index, controller_params(version: 'private')
          assert_response 200
          pattern = []
          Account.current.scoreboard_levels.each do |sb_level|
            pattern << scoreboard_level_pattern(sb_level)
          end
          match_json(pattern)
        ensure
          User.any_instance.unstub(:privilege?)
        end

        def test_index_without_manage_users_privilege
          User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
          User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
          get :index, controller_params(version: 'private')
          assert_response 403
        ensure
          User.any_instance.unstub(:privilege?)
        end
      end
    end
  end
end
