module HelpWidgets
  class SuggestedArticleRulesController < ApiApplicationController
    include HelpWidgets::SuggestedArticleRulesConstants

    decorate_views

    before_filter :check_feature

    private

      def scoper
        current_widget = current_account.help_widget_from_cache(params[:help_widget_id])
        return render_request_error(:invalid_help_widget, 400, id: @current_widget) unless current_widget

        current_widget.help_widget_suggested_article_rules_from_cache
      end

      def load_objects
        @items = scoper
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
  end
end
