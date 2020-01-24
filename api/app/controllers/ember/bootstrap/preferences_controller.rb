module Ember
  module Bootstrap
    class PreferencesController < ApiApplicationController
      def show
        # preferences delegator will return the preferences
      end

      def update
        controller_params = params[cname]
        controller_params.permit(*AgentConstants::PREFERENCES_FIELDS)

        agent = Ember::AgentPreferencesValidation.new(controller_params, @item)
        if agent.valid?(action_name.to_sym)
          @item.update_attributes(controller_params)
          render :show
        else
          render_custom_errors(agent, true)
        end
      end

      private

        def load_object
          @item = current_user.agent
          log_and_render_404 unless @item
        end
    end
  end
end
