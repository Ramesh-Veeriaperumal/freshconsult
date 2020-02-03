module Ember
  module Admin
    module Gamification
      class ScoreboardLevelsController < ApiApplicationController
        decorate_views(decorate_objects: [:index])

        def index
          response.api_root_key = :agent_levels
          super
        end

        private

          def scoper
            current_account.scoreboard_levels
          end
      end
    end
  end
end
