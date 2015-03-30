module Admin::Ecommerce::AccountsHelper

	def check_status(ecom_acc)
		if ecom_acc.active
			content_tag(:div, t('admin.ecommerce.active'))
		else
			content_tag(:div, t('admin.ecommerce.inactive'), :class => "text-error")
		end
	end

end
