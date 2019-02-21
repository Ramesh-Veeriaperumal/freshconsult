module ReportsHelper
  
  include Redis::RedisKeys
  include Redis::OthersRedis
  
  def productivity_report?
    current_account.performance_report_enabled? || feature?(:enterprise_reporting) || (current_account.timesheets_enabled? && privilege?(:view_time_entries))
  end

  def current_start_time
    
  end
  
  def current_end_time
    
  end

  def report_item(item_info)
      link_info = %( <span class="report-classic">#{t('reports.classic')}</span> ) if item_info[:classic]
  		link_content = %(#{link_info} <div class="img-outer">
	                    	<img width="70px" height="70px" src="#{spacer_image_url}" class = "reports-icon-#{ item_info[:class] }" />
	                    </div>
	                    <div class="report-icon-text">#{item_info[:label]}</div>)

	    content_tag( :li, link_to( link_content.html_safe, item_info[:url].html_safe ) )
	end

  #Icon for new reports(BETA)
  def helpdesk_report_item(item_info)
      link_content = %(<div class="img-outer">
                        <img width="70px" height="70px" src="#{spacer_image_url}" class = "reports-icon-#{ item_info[:class] }" />
                      </div>
                      <div class="report-icon-text"><div class="beta-tag"></div>#{item_info[:label]}</div>)

      content_tag( :li, pjax_link_to( link_content.html_safe, item_info[:url].html_safe ) )
  end
  
  def freshfone_reports?
    feature?(:freshfone) && !current_account.freshfone_numbers.empty?
  end

  def reports_ticket_link(content)
    trimmed_content = h(content).length > 73 ? (h(content).slice(0,73) + '...') : content
    if content.is_a?(Helpdesk::ArchiveTicket)
      content_tag(:a,trimmed_content,:href => helpdesk_archive_ticket_path(content.display_id),:target => "_blank")
    else

      content_tag(:a,trimmed_content,:href => helpdesk_ticket_path(content.display_id),:target => "_blank")
    end
  end
  
end