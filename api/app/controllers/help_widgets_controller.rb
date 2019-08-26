class HelpWidgetsController < ApiApplicationController
  include HelperConcern
  include HelpWidgetConcern
  include HelpWidgetConstants
  include FrustrationTrackingConcern

  before_filter :check_feature

  decorate_views

  def index
    super
    response.api_meta = { limit: current_account.account_additional_settings_from_cache.widget_count }
  end

  def create
    return unless validate_delegator(@item, product_id: cname_params[:product_id])

    if @item.save!
      render_201_with_location(item_id: @item.id)
    else
      render_custom_errors
    end
  end

  def update
    remove_predictive_cname_params unless preserve_predictive?
    delegator_hash = {
      product_id: cname_params[:product_id],
      settings: cname_params[:settings],
      freshmarketer: cname_params[:freshmarketer]
    }
    (return unless validate_delegator(@item, delegator_hash))

    if predictive_support_toggled?
      unless freshmarketer_signup && toggle_predictive_support
        return render_client_error
      end
    elsif param_domain_list.present?
      update_freshmarketer_domain(true)
    end
    cname_params[:settings] = @item.settings.deep_merge(cname_params[:settings].symbolize_keys || {}) unless cname_params[:settings].nil?
    @item.update_attributes(cname_params)
  end

  def destroy
    @item.active = false
    toggle_predictive_support(false) if @item.predictive?
    @item.save
    head 204
  end

  private

    def scoper
      current_account.help_widgets.active
    end

    def build_object
      super
      @item.name = widget_name if cname_params[:name].blank?
      @item.settings = assign_default_settings(cname_params[:settings], cname_params[:product_id])
    end

    def constants_class
      HelpWidgetConstants
    end

    def sanitize_params
      downcase_domain_list
    end

    def validate_params
      validate_widget_count if create?
      cname_params.permit(*HelpWidgetConstants::HELP_WIDGET_FIELDS)
      cname_params[:freshmarketer].permit(*HelpWidgetConstants::FRESHMARKETER_FIELDS) if cname_params.key?('freshmarketer')
      widget = validation_klass.new(cname_params, @item, string_request_params?)
      render_custom_errors(widget, true) unless widget.valid?(action_name.to_sym)
    end

    def check_feature
      render_request_error(:require_feature, 403, feature: :help_widget) unless current_account.help_widget_enabled?
    end

    def widget_name
      I18n.t('help_widget.untitled_widget',
             count: current_account.help_widgets.active.where(product_id: cname_params[:product_id]).count + 1)
    end

    def validate_url_params
      params.permit(*ApiConstants::DEFAULT_PARAMS)
    end

    def preserve_predictive?
      predictive_support_toggled? ? settings[:components][:predictive_support] : @item.predictive?
    end

    def validate_widget_count
      widget_count = Account.current.account_additional_settings_from_cache.widget_count
      render_request_error(:widget_limit_exceeded, 400, widget_count: widget_count) if Account.current.help_widgets.active.count >= widget_count
    end
end
