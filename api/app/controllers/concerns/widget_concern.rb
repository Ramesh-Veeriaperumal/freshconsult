module WidgetConcern
  extend ActiveSupport::Concern

  def validate_widget
    @widget_id = request.env['HTTP_X_WIDGET_ID']
    return render_request_error(:widget_id_not_given, 400) unless @widget_id
    @help_widget = current_account.help_widget_from_cache(@widget_id.to_i)
    render_request_error(:invalid_help_widget, 400, id: @widget_id) unless @help_widget
  end

  def set_widget_portal_as_current
    # set current portal if widget is associated to product 
    @current_portal = current_account.portals.find_by_product_id(@help_widget.product_id) || @current_portal
  end
end
