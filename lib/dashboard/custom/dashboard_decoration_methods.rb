module Dashboard::Custom::DashboardDecorationMethods
  def decorate_dashboard(item)
    CustomDashboardDecorator.new(item, {})
  end

  def decorate_dashboard_list(items)
    items.map { |item| decorate_dashboard(item).to_list_hash }
  end

  def dashboard_details_hash(item)
    decorate_dashboard(item).to_detail_hash
  end
end
