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

      def shift_service_request
        proxy_response = perform_shift_request(params, cname_params)
        response_body = proxy_response[:body]
        if success? proxy_response[:code]
          if index_page?
            @items = response_body['data']
            response.api_meta = response_body['meta']
          else
            @item = response_body
            response.status = proxy_response[:code]
          end
        elsif response_body['errors'].present?
          errors = { 'errors' => response_body['errors'] }
          render_request_error_with_info(response_body['code'].try(:to_sym), proxy_response[:code], errors, errors)
        else
          index_page? ? @items = [] : render_request_error(response_body['code'].try(:to_sym), proxy_response[:code])
        end
      end

      def validate_params
        if params[cname].blank?
          render_errors([[:payload, :invalid_json]])
        else
          shift_validation = shift_validation_class.new(params[cname], Account.current.agents_details_pluck_from_cache.map(&:first))
          if shift_validation.invalid?(params[:action].to_sym)
            render_errors(shift_validation.errors, shift_validation.error_options)
          else
            check_shift_params
          end
        end
      end

      def shift_validation_class
        'Admin::ShiftValidation'.constantize
      end

      def launch_party_name
        FeatureConstants::AGENT_SHIFTS
      end
  end
end
