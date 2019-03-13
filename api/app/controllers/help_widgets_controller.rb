class HelpWidgetsController < ApiApplicationController
  include HelperConcern
  include HelpWidgetConcern
  include HelpWidgetConstants
  include PredictiveSupportConcern

  before_filter :check_feature
  skip_before_filter :load_object, only: :freshmarketer_info

  decorate_views

  def create
    return unless validate_delegator(@item, product_id: cname_params[:product_id])
    if @item.save!
      render_201_with_location(item_id: @item.id)
    else
      render_custom_errors
    end
  end

  def update
    delegator_hash = {
      product_id: cname_params[:product_id],
      settings: cname_params[:settings]
    }
    (return unless validate_delegator(@item, delegator_hash))
    if predictive_support_toggled?
      unless toggle_predictive_support(cname_params[:settings][:components][:predictive_support])
        return render_request_error(:error_in_predictive_support, 400)
      end
    elsif domain_list_from_param
      update_freshmarketer_domain(true)
    end
    cname_params[:settings] = @item.settings.deep_merge(cname_params[:settings].symbolize_keys) if cname_params[:settings].present?
    @item.update_attributes(cname_params)
  end

  def destroy
    @item.active = false
    toggle_predictive_support(false)
    @item.save
    head 204
  end

  def freshmarketer_info
    @info = freshmarketer_details
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
      remove_predictive_cname_params if predictive_disabled?
      cname_params.permit(*HelpWidgetConstants::HELP_WIDGET_FIELDS)
      widget = validation_klass.new(cname_params, @item, string_request_params?)
      render_custom_errors(widget, true) unless widget.valid?(action_name.to_sym)
    end

    def check_feature
      log_and_render_404 unless current_account.help_widget_enabled?
    end

    def widget_name
      I18n.t('help_widget.untitled_widget',
             count: current_account.help_widgets.active.where(product_id: cname_params[:product_id]).count + 1)
    end

    def validate_url_params
      params.permit(*ApiConstants::DEFAULT_PARAMS)
    end

    def predictive_disabled?
      predictive_support_toggled? &&
        !cname_params[:settings][:components][:predictive_support]
    end

end
