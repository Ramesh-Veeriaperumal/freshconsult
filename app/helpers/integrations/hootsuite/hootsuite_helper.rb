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

  def show_clear_filter
  	(params[:search_text].present? || params[:ticket_status].present? || params[:ticket_priority].present?) and params[:active].present?
  end

  def logout_redirect_url
  	url = URI.parse(AppConfig['integrations_url'][Rails.env])
  	url.query = {:uid => params[:uid],:pid => params[:pid],:ts => params[:ts],:token => params[:token]}.to_query
  	url.path = integrations_hootsuite_home_domain_page_path
  	url.to_s
  end
end