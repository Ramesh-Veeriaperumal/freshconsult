module Utils
  module Unhtml
    def populate_content_create(item,*elements)
      elements.flatten!
      elements.each do |body|
        if item.send(:read_attribute,body).blank? && !item.send(:read_attribute , "#{body}_html").blank?
          item.send(:write_attribute , body, Helpdesk::HTMLSanitizer.plain(item.send(:read_attribute,"#{body}_html")))
        elsif item.send(:read_attribute , "#{body}_html").blank? && !item.send(:read_attribute,body).blank?
          item.send(:write_attribute , "#{body}_html",  body_html_with_formatting(CGI.escapeHTML(item.send(:read_attribute,body))))
        elsif item.send(:read_attribute,body).blank? && item.send(:read_attribute , "#{body}_html").blank?
          item.send(:write_attribute , "#{body}_html", I18n.t('not_given'))
          item.send(:write_attribute , body,I18n.t('not_given'))
        end
        text = Nokogiri::HTML(item.send(:read_attribute,"#{body}_html"))
        unless text.at_css("body").blank?
          text.xpath("//del").each { |div|  div.name= "span";}
          text.xpath("//p").each { |div|  div.name= "div";}
          item.send(:write_attribute , "#{body}_html", Rinku.auto_link(text.at_css("body").inner_html, :urls))
        end
      end
    end

    def body_html_with_formatting(body)
      body_html = Rinku.auto_link(body) { |text| truncate(text, 100) }
      textilized = RedCloth.new(body_html.gsub(/\n/, '<br />'), [ :hard_breaks ])
      textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
      white_list(textilized.to_html)
    end
  end
end
