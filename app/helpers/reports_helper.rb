module ReportsHelper
  def current_start_time
    
  end
  
  def current_end_time
    
  end

  def report_item(item_info)
	    link_content = image_tag( "/images/spacer.gif", :class => "reports-icon-#{ item_info[:class] }", :width => 60, :height =>60 ) +
	                   content_tag( :div, item_info[:label] )
	    content_tag( :li, link_to( link_content, item_info[:url] ) )
	end
  
end