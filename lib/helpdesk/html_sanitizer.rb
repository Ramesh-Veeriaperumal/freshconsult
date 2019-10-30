module Helpdesk::HTMLSanitizer

  require 'html_to_plain_text'
   
  def self.clean(html)
    if html
      tokenized_html = get_tokenized_html(html)
      begin
        Sanitize.fragment(tokenized_html, Sanitize::Config::IMAGE_RELAXED)
      rescue Exception => e
        Sanitize.fragment(tokenized_html, Sanitize::Config::HTML_RELAXED)
      end
    end
  end

  def self.sanitize_ticket(html)
    if html
      tokenized_html = get_tokenized_html(html)
      begin
        Sanitize.fragment(tokenized_html, Sanitize::Config::TICKET_RELAXED_WITH_IMAGE)
      rescue
        Sanitize.fragment(tokenized_html, Sanitize::Config::TICKET_RELAXED_WITH_HTML)
      end
    end
  end
  
  def self.plain(html)
    plain_text(Sanitize.fragment(html, Sanitize::Config::ADDITIONAL_DEFAULT_CONFIG)) if html
  end

  def self.sanitize_article(html)
    if html
      begin
        Sanitize.fragment(html, Sanitize::Config::ARTICLE_WHITELIST) 
      rescue Exception => e
        Sanitize.fragment(html, Sanitize::Config::HTML_RELAXED) 
      end
    end
  end

  def self.sanitize_post(html)
    if html
      begin
        Sanitize.fragment(FDRinku.auto_link(html), Sanitize::Config::POST_WHITELIST) 
      rescue Exception => e
        Sanitize.fragment(FDRinku.auto_link(html), Sanitize::Config::HTML_RELAXED) 
      end
    end
  end

  def self.sanitize_for_insert_solution(html)
    if html
      begin
        Sanitize.fragment(html, Sanitize::Config::INSERT_SOLUTION_WHITELIST) 
      rescue Exception => e
        Sanitize.fragment(html, Sanitize::Config::HTML_RELAXED) 
      end
    end
  end

  def self.html_to_plain_text(html)
    HtmlToPlainText.plain_text(html)
  end

  private
  
    def self.plain_text(html)
      CGI::unescapeHTML(html)
    end

    def self.get_tokenized_html(html)
      (!Account.current.launched?(:encode_emoji) and Account.current.features?(:tokenize_emoji)) ? html.tokenize_emoji : html
    end
end
