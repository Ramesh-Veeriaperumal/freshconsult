module ReportsHelper
  def current_start_time
    
  end
  
  def current_end_time
    
  end

  	def report_item(item_info)
      link_info = %( <span class="report-classic">#{t('reports.classic')}</span> ) if item_info[:classic]
  		link_content = %(#{link_info} <div class="img-outer">
	                    	<img width="70px" height="70px" src="/images/misc/spacer.gif" class = "reports-icon-#{ item_info[:class] }" />
	                    </div>
	                    <div class="report-icon-text">#{item_info[:label]}</div>)

	    content_tag( :li, link_to( link_content.html_safe, item_info[:url].html_safe ) )
	end

  def freshfone_reports?
    feature?(:freshfone) && !current_account.freshfone_numbers.empty?
  end
  
end