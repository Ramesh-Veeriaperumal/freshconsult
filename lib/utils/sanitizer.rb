module Utils
  module Sanitizer
    include Utils::Unhtml

    def sanitize_body_and_unhtml_it(item, *elements)
      elements.each do |element|
        element_html = element+"_html"
        if item.send(element_html) && (new_record? || item.send(element_html+"_changed?"))
          item.send(:write_attribute,element_html,
                               Helpdesk::HTMLSanitizer.clean(item.send(element_html)))
        end
      end
      populate_content_create(item, *elements) if new_record?
    end

    def sanitize_body_hash(attributes,nested_attribute, *elements)
      elements.each do |element|
        element_html = (element+"_html").to_sym
        element = element.to_sym
        if(attributes[nested_attribute] &&
           attributes[nested_attribute][element_html])

          attributes[nested_attribute][element_html] =
            Rinku.auto_link(Helpdesk::HTMLSanitizer.clean(attributes[nested_attribute][element_html]), :urls)
          attributes[nested_attribute][element]=
            Helpdesk::HTMLSanitizer.plain(attributes[nested_attribute][element_html]).strip
        end
      end
      attributes
    end

  end
end
