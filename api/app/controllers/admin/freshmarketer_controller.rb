module Admin
  class FreshmarketerController < ApiApplicationController
    include FreshmarketerConcern
    COLLECTION_RESPONSE_FOR = [].freeze
    def index
      if session_replay_linked? || frustration_tracking_linked?
        if session_replay_linked?
          freshmarketer_client.experiment
          experiment_hash = experiment_details
          return render_client_error if client_error?
        end
        @index_data = {
          linked: true,
          predictive: frustration_tracking_linked?,
          experiment: experiment_hash,
          name: account_additional_settings.freshmarketer_name
        }
      else
        @index_data = { linked: false, experiment: {} }
      end
    end

    def link
      return unless validate_request(cname_params)
      freshmarketer_client.link_account(cname_params[:value], cname_params[:type])
      return render_client_error if client_error?
      head 204
    end

    def unlink
      freshmarketer_client.unlink_account
      head 204
    end

    def enable_session_replay
      freshmarketer_client.enable_session_replay
      return render_client_error if client_error?

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

    def domains
      freshmarketer_client.domains
      return render_client_error if client_error?

      @domains = { domains: freshmarketer_client.response_data['domains'] }
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

      def session_replay_linked?
        @session_replay_linked ||= current_account.account_additional_settings.freshmarketer_linked?
      end

      def frustration_tracking_linked?
        @frustration_tracking_linked ||= current_account.account_additional_settings.frustration_tracking_fm_linked?
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
