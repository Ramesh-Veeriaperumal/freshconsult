module Proactive
  class RulesController < ApiApplicationController
    include ::Proactive::ProactiveJwtAuth
    include ::Proactive::Constants
    include ::Proactive::ProactiveUtil

    before_filter :check_proactive_feature, :generate_jwt_token
    skip_before_filter :build_object, only: [:create]
    skip_before_filter :load_object, only: [:destroy, :show, :update]

    def create
      service_response = make_http_call(PROACTIVE_SERVICE_ROUTES[:rules_route], 'post')
      render :create, status: service_response[:status]
    end

    def index
      request_params = ''
      request_params += "per_page=#{params[:per_page]}&" if params[:per_page].present?
      request_params += "page=#{params[:page]}&" if params[:page].present?
      route = request_params == '' ? PROACTIVE_SERVICE_ROUTES[:rules_route] : "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}?#{request_params.chop}"
      service_response = make_http_call(route, 'get')
      add_link_header(page: (page.to_i + 1)) if service_response[:headers].present? && service_response[:headers]['link'].present?
      render :index, status: service_response[:status]
    end

    def show
      route = "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}/#{params[:id]}"
      service_response = make_http_call(route, 'get')
      if @item.present?
        render :show, status: service_response[:status]
      else
        head service_response[:status]
      end
    end

    def update
      route = "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}/#{params[:id]}"
      service_response = make_http_call(route, 'put')
      if @item.present?
        render :update, status: service_response[:status]
      else
        head service_response[:status]
      end
    end

    def destroy
      route = "#{PROACTIVE_SERVICE_ROUTES[:rules_route]}/#{params[:id]}"
      service_response = make_http_call(route, 'delete')
      if @item.present?
        render :delete, status: service_response[:status]
      else
        head service_response[:status]
      end
    end

    private

      def generate_jwt_token
        jwt_payload = { account_id: current_account.id, sub: 'helpkit' }
        @auth = "Token #{sign_payload(jwt_payload)}"
      end

      def check_proactive_feature
        render_request_error(:require_feature, 403, feature: 'Proactive Support') unless current_account.proactive_outreach_enabled?
      end
  end
end
