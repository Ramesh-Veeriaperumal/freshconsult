module Admin::WidgetConfigHelper
	def widget_asset_url(https = false)
		Helpdesk::ASSET_URL[Rails.env.to_sym]
	end
end
