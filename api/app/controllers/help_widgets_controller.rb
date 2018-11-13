class HelpWidgetsController < ApiApplicationController
  include HelperConcern
  include HelpWidgetConcern
  include HelpWidgetConstants

  before_filter :check_feature

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
    (return unless validate_delegator(@item, product_id: cname_params[:product_id])) if cname_params[:product_id]
    cname_params[:settings] = @item.settings.deep_merge(cname_params[:settings].symbolize_keys) if cname_params[:settings]
    @item.update_attributes(cname_params)
  end

  def destroy
    @item.active = false
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

    def validate_params
      cname_params.permit(*HelpWidgetConstants::HELP_WIDGET_FIELDS)
      widget = validation_klass.new(cname_params, @item, string_request_params?)
      render_custom_errors(widget, true) unless widget.valid?(action_name.to_sym)
    end

    def check_feature
      log_and_render_404 unless current_account.help_widget_enabled?
    end

    def widget_name
      I18n.t('help_widget.untitled_widget', 
        count: current_account.help_widgets.active.where(:product_id => cname_params[:product_id]).count + 1)
    end

    def validate_url_params
      params.permit(*ApiConstants::DEFAULT_PARAMS)
    end
end
