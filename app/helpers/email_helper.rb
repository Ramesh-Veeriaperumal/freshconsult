module EmailHelper
	include ActionView::Helpers::NumberHelper
	
	def attachment_exceeded_message(size)
		I18n.t('attachment_limit_failed_message', :size => number_to_human_size(size)).html_safe
	end
end
