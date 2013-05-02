module ReportsHelper
  def current_start_time
    
  end
  
  def current_end_time
    
  end

  	def report_item(item_info)
  		link_content = %(<span class="report-classic">Classic</span><div class="img-outer">
	                    	<img width="70px" height="70px" src="/images/spacer.gif" class = "reports-icon-#{ item_info[:class] }" />
	                    </div>
	                    <div class="report-icon-text">#{item_info[:label]}</div>)

	    content_tag( :li, link_to( link_content, item_info[:url] ) )
	end
  
end