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
   plain_text(Sanitize.clean(html)) if html
  end

  private
  
    def self.plain_text(html)
      CGI::unescapeHTML(html)
    end
end
