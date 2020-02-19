module HelpWidgets
  class SuggestedArticleRulesController < ApiApplicationController
    include HelpWidgets::SuggestedArticleRulesConstants
    include HelperConcern

    decorate_views

    before_filter :check_feature
    before_filter :fetch_widget
    before_filter :check_rule_limit, only: [:create]
    before_filter :load_object, only: [:show, :update, :destroy]
    before_filter :validate_params, only: [:create, :update]
    before_filter :sanitize_params, only: [:create, :update]
    before_filter :build_object, only: [:create]

    def create
      return unless validate_delegator(@help_widget, cname_params[:filter])

      super
    end

    def update
      if cname_params.key?('filter')
        return unless validate_delegator(@help_widget, cname_params[:filter])
      end
      super
    end

    private

      def scoper
        @help_widget.help_widget_suggested_article_rules_from_cache
      end

      def load_objects
        @items = scoper
      end

      def validate_params
        cname_params.permit(*CREATE_FIELDS)
        rules_validation = validation_klass.new(cname_params, @item, string_request_params?)
        render_custom_errors(rules_validation, true) unless rules_validation.valid?(action_name.to_sym)
      end

      def load_object(items = scoper)
        @item = items.find { |rule| rule.id == params[:id].to_i } if items
        log_and_render_404 unless @item
      end

      def validate_filter_params
        params.permit(*LIST_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
        rules_filter = HelpWidgets::SuggestedArticleRulesFilterValidation.new(params, nil, string_request_params?)
        render_errors(rules_filter.errors, rules_filter.error_options) unless rules_filter.valid?
      end

      def check_feature
        return if current_account.help_widget_enabled? && current_account.help_widget_article_customisation_enabled?

        render_request_error(:require_feature, 403, feature: 'help_widget, help_widget_article_customisation')
      end

      def constants_class
        HelpWidgets::SuggestedArticleRulesConstants
      end

      def sanitize_params
        cname_params[:conditions] = rule_conditions if cname_params[:conditions]
        cname_params[:rule_operator] ||= HelpWidgetSuggestedArticleRule::RULE_OPERATOR[:OR]
        cname_params[:filter] = HelpWidgetSuggestedArticleRule::DEFAULT_FILTER.dup.merge(cname_params[:filter]) if cname_params[:filter]
      end

      def rule_conditions
        default_condition = HelpWidgetSuggestedArticleRule::DEFAULT_CONDITION.dup
        conditions = begin
          cname_params[:conditions].each_with_object([]) do |value, resultant_array|
            resultant_array << default_condition.merge(value)
          end
        end
        conditions
      end

      def fetch_widget
        @help_widget = current_account.help_widget_from_cache(params[:help_widget_id])
        render_request_error(:invalid_help_widget, 400, id: params[:help_widget_id]) unless @help_widget
      end

      def check_rule_limit
        render_request_error(:rule_limit_exceeded, 400, limit: DEFAULT_RULE_LIMIT) if scoper.size >= DEFAULT_RULE_LIMIT
      end

      def render_201_with_location(template_name: "#{controller_path.gsub(NAMESPACED_CONTROLLER_REGEX, '')}/#{action_name}")
        render template_name, location_url: safe_send('help_widget_suggested_article_rules_url', @item.id), status: 201
      end
  end
end
