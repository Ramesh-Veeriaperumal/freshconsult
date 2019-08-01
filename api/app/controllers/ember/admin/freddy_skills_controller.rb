module Ember
  module Admin
    class FreddySkillsController < ApiApplicationController
      include ::Admin::FreddyConstants

      skip_before_filter :before_load_object, :load_object, :after_load_object
      before_filter :check_eligibility, only: [:show, :update]

      def index
        @response = FREDDY_SKILLS_ELIGIBILITY.each_with_object([]) do |(skill, eligibility), skills|
          skills << construct_response(skill) if eligible_skill?(eligibility)
        end
      end

      def show
        @response = construct_response(params[:name].to_sym)
      end

      def update
        skill = params[:name].to_sym
        if params[cname][:enabled] == true
          current_account.add_feature(skill)
          execute_callbacks(skill, :enable)
        elsif params[cname][:enabled] == false
          current_account.revoke_feature(skill)
          execute_callbacks(skill, :disable)
        end
        @response = construct_response(skill)
      end

      private

        def check_eligibility
          log_and_render_404 unless eligible_skill?(FREDDY_SKILLS_ELIGIBILITY[params[:name].to_sym])
        end

        def eligible_skill?(eligibility)
          eligibility.present? && current_account.has_feature?(eligibility)
        end

        def construct_response(skill)
          {}.tap do |response|
            response[:name] = skill
            response[:enabled] = current_account.has_feature?(skill)
          end
        end

        def execute_callbacks(skill, action)
          if CALLBACKS[skill] && CALLBACKS[skill][action]
            current_account.safe_send(CALLBACKS[skill][action])
          end
        end
    end
  end
end
