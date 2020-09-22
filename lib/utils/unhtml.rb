module Utils
  module Unhtml
    def populate_content_create(item,*elements)
      elements.flatten!
      elements.each do |body|
        if item.safe_send(:read_attribute,body).blank? && !item.safe_send(:read_attribute , "#{body}_html").blank?
          item.safe_send(:write_attribute , body, Helpdesk::HTMLToPlain.plain(item.safe_send(:read_attribute,"#{body}_html")).strip)
        elsif item.safe_send(:read_attribute , "#{body}_html").blank? && !item.safe_send(:read_attribute,body).blank?
          item.safe_send(:write_attribute , "#{body}_html",  body_html_with_formatting(CGI.escapeHTML(item.safe_send(:read_attribute,body))))
        elsif item.safe_send(:read_attribute,body).blank? && item.safe_send(:read_attribute , "#{body}_html").blank?
          item.safe_send(:write_attribute , "#{body}_html", I18n.t('not_given'))
          item.safe_send(:write_attribute , body,I18n.t('not_given'))
        end
        text = Nokogiri::HTML(item.safe_send(:read_attribute,"#{body}_html"))
        unless text.at_css("body").blank?
          text.xpath("//del").each { |div|  div.name= "span";}
          text.xpath("//p").each { |div|  div.name= "div";}
          auto_linked_html = FDRinku.auto_link(text.at_css("body").inner_html, { :attr => 'rel="noreferrer"' })
          item.send(:write_attribute , "#{body}_html", auto_linked_html.gsub('%7B','{').gsub('%7D','}'))
          #substituting parsed placeholder %7B %7D to {{ }} - the change is done to support canned response, will run for other models as well.  
        end
      end
    end

    def body_html_with_formatting(body)
      body_html = FDRinku.auto_link(body, { :mode => :all, :attr => 'rel="noreferrer"' }) { |text| truncate(text, :length => 100) }
      textilized = RedCloth.new(body_html.gsub(/\n/, '<br />'), [ :hard_breaks ])
      textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
      white_list(textilized.to_html)
    end

    def body_html_with_tags_renamed(html_string)
      html_doc = Nokogiri::HTML(html_string)
      unless html_doc.at_css("body").blank?
        html_doc.xpath("//del").each { |div|  div.name= "span";}
        html_doc.xpath("//p").each { |div|  div.name= "div";}
      end
      FDRinku.auto_link(html_doc.at_css("body").inner_html, { :attr => 'rel="noreferrer"' })
    end

  end
end
