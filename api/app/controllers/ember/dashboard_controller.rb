module Ember
  class DashboardController < ApiApplicationController
    include Gamification::GamificationUtil
    include Community::ModerationCount
    include ::Dashboard::UtilMethods
    include DashboardConcern
    include HelperConcern
    include SolutionConcern

    before_filter :set_dashboard_type
    before_filter :survey_active?, only: [:survey_info]
    before_filter :validate_language, only: [:show]
    before_filter :validate_privilege?, only: [:show]
    around_filter :run_on_slave
    around_filter :use_time_zone, only: [:scorecard, :ticket_trends, :ticket_metrics, :survey_info] # Uses user/account's zone instead of UTC

    skip_before_filter :load_object

    attr_accessor :dashboard_type, :widget_privileges
    def scorecard
      return unless validate_query_params
      # if validate_dashboard_delegator
      assign_and_sanitize_params
      scorecard_fields = ROLE_BASED_SCORECARD_FIELDS[dashboard_type.to_sym]
      options = {}
      options[:trends] = scorecard_fields
      options[:filter_options] = {}
      options[:filter_options][:group_id] = params[:group_id] if params.key?(:group_id)
      options[:filter_options][:product_id] = params[:product_id] if params.key?(:product_id)
      options[:is_agent] = dashboard_type.include?('agent')
      scorecard_hash = ::Dashboard::SearchServiceTrendCount.new(options).fetch_count
      scorecard_hash = parse_scorecard_hash(scorecard_hash, options[:trends])
      @scorecard = {}
      # ember needs an id to store it in model,so building scorecard hash with id.
      scorecard_hash.each_with_index do |(key, value), index|
        @scorecard[key] = {
          id: index,
          name: key,
          value: value
        }
      end
      # end
    end

    def show
      # ember needs an id to store it in model,so building the hash with id.
      @config = {}
      @config[:widgets] = omni_privilege? ? omnichannel_widget_config : widget_config
      @config[:id] = params['id']
    end

    def survey_info
      return unless validate_query_params
      assign_and_sanitize_params
      # ember needs an id to store it in model,so building the hash with id.
      if params[:group_id].present? && params[:group_id].is_a?(Array) # in omni dashboard we send group ids params.
        options = { group_ids: params[:group_id] }
        options[:time_range] = INVERTED_TIME_PERIODS['day']
        @widget_count = ::Dashboard::SurveyWidget.new.filtered_records(options)
      else
        options = { group_id: params[:group_id] }
        options[:is_agent] = dashboard_type.include?('agent')
        @widget_count = ::Dashboard::SurveyWidget.new.fetch_records(options)
      end
      csat_response = CSAT_FIELDS.deep_dup
      @widget_count[:results].each do |key, val|
        csat_response[key.downcase.to_sym][:value] = val
      end

      @widget_count[:results] = csat_response.values
      @widget_count[:id] = 1
    end

    def unresolved_tickets_data
      return unless validate_query_params
      # if validate_dashboard_delegator
      assign_and_sanitize_params
      load_unresolved_filter
      @unresolved_tickets = fetch_unresolved_tickets
      # end
    end

    def moderation_count
      fetch_spam_counts
      @counts
    end

    def ticket_trends
      return unless validate_query_params
      # if validate_dashboard_delegator
      assign_and_sanitize_params
      @result = ::Dashboard::AdminRedshiftWidget.new(params).fetch_dashboard_trends
      render_base_error(:internal_error, 503) if @result[:errors].present?
      # end
    end

    def ticket_metrics
      return unless validate_query_params
      # if validate_dashboard_delegator
      assign_and_sanitize_params
      @result = ::Dashboard::AdminRedshiftWidget.new(params).fetch_dashboard_metrics
      render_base_error(:internal_error, 503) if @result[:errors].present?
      # end
    end

    private

      def survey_active?
        return access_denied unless current_account.any_survey_feature_enabled_and_active?
      end

      # Validating w.r.t default dashboard request vs privileage he has
      # i.e agent request for default dashboard has manage_tickest --> true
      # i.e agent request for default dashboard has create_and_edit_articles and no manage_tickest --> 403
      # i.e agent request for default solution dashboard has create_and_edit_articles --> true
      # i.e agent request for default solution dashboard has manage_tickest no create_and_edit_articles --> 403
      def validate_privilege?
        has_privilege = false
        if is_sol_dashboard?
          has_privilege = current_user.privilege?(:create_and_edit_article) && current_account.solutions_dashboard_enabled?
        else
          has_privilege = current_user.privilege?(:manage_tickets)
        end
        render_request_error(:access_denied, 403) unless has_privilege 
      end

      def omni_privilege?
        Account.current.omni_channel_dashboard_enabled? && current_user.privilege?(:view_reports)
      end
  end
end
