module Integrations::Hootsuite::HootsuiteHelper
	def hootsuite_datetime_format(date_time, options={})
		default_options = {
			:include_weekday => false
		}
		options = default_options.merge(options)

		day_text = '';
		time_format = "at %l:%M %p"

		if(Date.yesterday == date_time.to_date)
			day_text = t('yesterday')
		else 
			return formated_date(date_time, options);
		end

		day_text + " " + date_time.strftime(time_format);
  	end
end