module ReportsHelper
  
  include Redis::RedisKeys
  include Redis::OthersRedis
  
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
                      <div class="beta-tag"> BETA </div>
                      <div class="report-icon-text">#{item_info[:label]}</div>)

      content_tag( :li, link_to( link_content.html_safe, item_info[:url].html_safe ) )
  end
  
  def bi_reports_ui_enabled?
    feature?(:bi_reports) && ismember?(BI_REPORTS_UI_ENABLED, current_account.id)
  end

  def freshfone_reports?
    feature?(:freshfone) && !current_account.freshfone_numbers.empty?
  end
  
end