module Reports::TimesheetReportsHelper
	
	include Reports::GlanceReportsHelper

	def generate_pdf_action?
		params[:action] == "generate_pdf"
	end

  def timesheet_formatted_date(date_time, options={})
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

  def construct_timesheet_entry_row(headers, time_entry, load_time, is_pdf=false)
    entry = ""
    headers.each do |item|
      content = timesheet_formatted_date(time_entry.executed_at, {:format => :short_day_with_week, :include_year => true}) if item.eql?(:group_by_day_criteria)
      if(item.eql?(:hours))
        content ||= (time_entry.time_spent || 0) + (time_entry.timer_running ? (load_time - time_entry.start_time) : 0)
      else
        content ||= time_entry.send(item)
      end
      html_content = ""
      if item.eql?(:workable)
        if !is_pdf
          html_content = content_tag(:td, reports_ticket_link(content), :class => item)
        else
          html_content = "<td class=#{item}><div> #{h(content)} </div></td>"
        end
      else
        if(item.eql?(:hours))
          html_content = "<td class='hours'>"
            if time_entry.billable
              html_content += "<span class='billable-block' title='billable'>&nbsp;</span>#{get_time_in_hours(content)}"
            else
              html_content += "<span class='non-billable-block' title='non-billable'>&nbsp;</span>#{get_time_in_hours(content)}"
            end
          html_content += "</td>"
        else
          if( content.blank? || content.match(/^No +/) )
            content = "-"
          end
          html_content = content_tag(:td,h(content),:class => item)
        end
      end
      entry += html_content
    end
    return entry.html_safe
  end

end
