module Admin
  class FreshmarketerController < ApiApplicationController
    COLLECTION_RESPONSE_FOR = [].freeze
    def index
      linked = current_account.account_additional_settings.freshmarketer_linked?
      if linked
        freshmarketer_client.experiment
        return render_client_error if client_error?
      end
      @index_data = { linked: linked, experiment: linked ? experiment_details : {} }
    end

    def link
      return unless validate_request(cname_params)
      freshmarketer_client.link_account(cname_params[:value], (cname_params[:type] == 'create'))
      return render_client_error if client_error?
      head 204
    end

    def unlink
      freshmarketer_client.unlink_account
      head 204
    end

    def enable_integration
      freshmarketer_client.enable_integration
      return render_client_error if client_error?
      head 204
    end

    def disable_integration
      freshmarketer_client.disable_integration
      return render_client_error if client_error?
      head 204
    end

    def sessions
      validate_request(params)
      return log_and_render_404 unless load_ticket
      freshmarketer_client.recent_sessions(params[:filter] || @ticket.requester.try(:email) || current_user.email)
      return render_client_error if client_error?
      @sessions = sessions_data
      response.api_root_key = :sessions
    end

    def session_info
      validate_request(params)
      freshmarketer_client.session(params[:session_id])
      return render_client_error if client_error?
      @session_data = { url: freshmarketer_client.response_data['result'] }
      response.api_root_key = :session
    end

    private

      def load_ticket
        @ticket = current_account.tickets.permissible(api_current_user).find_by_display_id(params[:id])
      end

      def load_object
      end

      def validate_request(params)
        fields = "FreshmarketerConstants::#{action_name.upcase}_FIELDS".constantize
        params.permit(*fields)
      end

      def freshmarketer_client
        @freshmarketer_client ||= ::Freshmarketer::Client.new
      end

      def client_error?
        freshmarketer_client.response_code != :ok
      end

      def render_client_error
        case freshmarketer_client.response_code
        when :duplicate_email_id
          render_request_error(:fm_duplicate_email, 409)
        when :invalid_credentials, :invalid_access_key, :invalid_scope, :scope_restricted
          render_request_error(:fm_invalid_token, 403)
        when :invalid_domain_name, :invalid_email_id, :invalid_account_id, :invalid_request, :invalid_user
          render_request_error(:fm_invalid_request, 400)
        else
          render_base_error(:internal_error, 500)
        end
      end

      def experiment_details
        additional_settings = current_account.account_additional_settings
        experiment_hash = freshmarketer_client.response_data
        {
          name: experiment_hash['experiment_name'],
          url: experiment_hash['experiment_url'],
          status: experiment_hash['experiment_status'],
          cdn_script: additional_settings.freshmarketer_cdn_script,
          app_url: additional_settings.freshmarketer_app_url,
          integrate_url: additional_settings.freshmarketer_integrate_url
        }
      end

      def sessions_data
        freshmarketer_client.response_data.map do |session|
          {
            id: session['session_id'],
            recorded_on: Time.at(session['recorded_on'] / 1000).utc.iso8601,
            duration: Time.at(session['duration'] / 1000).utc.strftime('%H:%M:%S')
          }
        end
      end

      wrap_parameters(*wrap_params)
  end
end
