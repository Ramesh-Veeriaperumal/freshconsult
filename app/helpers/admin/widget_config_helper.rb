module Admin::WidgetConfigHelper
	def widget_asset_url
		Helpdesk::ASSET_URL[Rails.env.to_sym]
	end
end
