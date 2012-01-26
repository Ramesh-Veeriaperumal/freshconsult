module Helpdesk::HTMLSanitizer
   
  def self.clean(html)
   if html
    begin
      Sanitize.clean(html, Sanitize::Config::IMAGE_RELAXED) 
    rescue Exception => e
      Sanitize.clean(html, Sanitize::Config::HTML_RELAXED) 
    end  
   end
  end
  
  def self.plain(html)
    Sanitize.clean(html) if html
  end
end
