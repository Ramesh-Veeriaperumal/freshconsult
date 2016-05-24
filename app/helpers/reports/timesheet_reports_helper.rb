module Reports::TimesheetReportsHelper
	
	include Reports::GlanceReportsHelper

	def generate_pdf_action?
		params[:action] == "generate_pdf"
	end

  def pdf_formatted_date(date_time, options={})
    default_options = {
      :format => :short_day_with_time,
      :include_year => false,
      :include_weekday => true,
      :translate => true
    }
    options = default_options.merge(options)
    time_format =  (Account.current.date_type(options[:format]) if Account.current) || "%a, %-d %b, %Y at %l:%M %p"
    unless options[:include_year]
      time_format = time_format.gsub(/,\s.\b[%Yy]\b/, "") if (date_time.year == Time.now.year)
    end
    
    unless options[:include_weekday]
      time_format = time_format.gsub(/\A(%a|A),\s/, "")
    end
    final_date = options[:translate] ? (I18n.l date_time , :format => time_format) : (date_time.strftime(time_format))
  end

end
