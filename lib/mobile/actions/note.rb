module Mobile::Actions::Note
  
  def body_mobile
    body_html.index(">\n<div class=\"freshdesk_quote\">").nil? ? 
    body_html : body_html.slice(0..body_html.index(">\n<div class=\"freshdesk_quote\">"))
    body_html.gsub(/href=/,"target='_blank' href=");
  end

  def formatted_created_at(format = "%B %e %Y @ %I:%M %p")
    format = format.gsub(/.\b[%Yy]/, "") if (created_at.year == Time.now.year)
    created_at.strftime(format)
  end
end