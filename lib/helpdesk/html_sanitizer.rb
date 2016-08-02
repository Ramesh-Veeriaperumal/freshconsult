module Helpdesk::HTMLSanitizer
   
  def self.clean(html)
    if html
      tokenized_html = (Account.current.present? and Account.current.features?(:tokenize_emoji)) ? html.tokenize_emoji : html
      begin
        Sanitize.clean(tokenized_html, Sanitize::Config::IMAGE_RELAXED)
      rescue Exception => e
        Sanitize.clean(tokenized_html, Sanitize::Config::HTML_RELAXED)
      end
    end
  end
  
  def self.plain(html)
   plain_text(Sanitize.clean(html)) if html
  end

  def self.sanitize_article(html)
    if html
      begin
        Sanitize.clean(html, Sanitize::Config::ARTICLE_WHITELIST) 
      rescue Exception => e
        Sanitize.clean(html, Sanitize::Config::HTML_RELAXED) 
      end
    end
  end

  def self.sanitize_post(html)
    if html
      begin
        Sanitize.clean(Rinku.auto_link(html, :urls), Sanitize::Config::POST_WHITELIST) 
      rescue Exception => e
        Sanitize.clean(Rinku.auto_link(html, :urls), Sanitize::Config::HTML_RELAXED) 
      end
    end
  end

  def self.sanitize_for_insert_solution(html)
    if html
      begin
        Sanitize.clean(html, Sanitize::Config::INSERT_SOLUTION_WHITELIST) 
      rescue Exception => e
        Sanitize.clean(html, Sanitize::Config::HTML_RELAXED) 
      end
    end
  end

  private
  
    def self.plain_text(html)
      CGI::unescapeHTML(html)
    end
end
