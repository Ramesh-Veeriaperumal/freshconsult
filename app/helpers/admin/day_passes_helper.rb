module Admin::DayPassesHelper
	include SubscriptionsHelper

	def day_pass_display_string(pass)
		content_tag(:span, t(".day_passes.index.day_pass_pack", :quantity => pass[0], :currency => fetch_currency_unit, 
			:amount => pass[1])) 
	end

end