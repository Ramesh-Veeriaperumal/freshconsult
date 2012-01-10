module Helpdesk::HTMLSanitizer
   
  def self.clean(html)
   if html
    begin
      puts "start"
      Sanitize.clean(html, Sanitize::Config::IMAGE_RELAXED) 
    rescue Exception => e
      puts "exception"
      Sanitize.clean(html, Sanitize::Config::HTML_RELAXED) 
    end  
   end
  end
  
  def self.plain(html)
    Sanitize.clean(html) if html
  end
end
