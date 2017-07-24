module Ember
  module Dashboard
    class QuestsController < ApiApplicationController
      include HelperConcern
      decorate_views

      def feature_name
        :gamification
      end

      private

        def scoper
          quest_scoper = current_account.quests
          quest_scoper = quest_scoper.available(current_user) if params[:filter] == 'unachieved'
          quest_scoper
        end

        def validate_filter_params
          @constants_klass = 'QuestConstants'
          @validation_klass = 'QuestFilterValidation'
          validate_query_params
        end
    end
  end
end
