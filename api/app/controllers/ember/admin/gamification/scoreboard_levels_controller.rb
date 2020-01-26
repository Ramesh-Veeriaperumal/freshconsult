module Ember
  module Admin
    module Gamification
      class ScoreboardLevelsController < ApiApplicationController
        decorate_views(decorate_objects: [:index])

        private

          def scoper
            current_account.scoreboard_levels
          end
      end
    end
  end
end
