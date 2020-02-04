module Admin
  class ShiftsController < ApiApplicationController
    include Admin::ShiftHelper
    skip_before_filter :load_object, :build_object
    before_filter :shift_service_request, only: %i[index show create update]

    def index; end

    def show; end

    def create; end

    def update; end

    def destroy
      head perform_shift_request(params, cname_params)[:code]
    end

    private

      def validate_params
        if params[cname].blank?
          render_errors([[:payload, :invalid_json]])
        else
          shift_validation = shift_validation_class.new(params[cname], Account.current.agents_details_from_cache.map(&:id))
          if shift_validation.invalid?(params[:action].to_sym)
            render_errors(shift_validation.errors, shift_validation.error_options)
          else
            check_controller_params
          end
        end
      end

      def check_controller_params
        params[cname].permit(*Admin::ShiftConstants::REQUEST_PERMITTED_PARAMS)
      end

      def shift_validation_class
        'Admin::ShiftValidation'.constantize
      end

      def launch_party_name
        FeatureConstants::AGENT_SHIFTS
      end
  end
end
