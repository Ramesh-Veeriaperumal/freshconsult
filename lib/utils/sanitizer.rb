module Utils
  module Sanitizer
    include Utils::Unhtml

    def sanitize_body_and_unhtml_it(item, *elements)
      elements.each do |element|
        element_html = element+"_html"
        if item.safe_send(element_html) && (new_record? || item.safe_send(element_html+"_changed?"))
          sanitized_html = is_ticket_sanitizer ? Helpdesk::HTMLSanitizer.sanitize_ticket(item.safe_send(element_html)) : Helpdesk::HTMLSanitizer.clean(item.safe_send(element_html))
          item.safe_send(:write_attribute,element_html,sanitized_html)
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

          sanitized_html = is_ticket_sanitizer ? Helpdesk::HTMLSanitizer.sanitize_ticket(attributes[nested_attribute][element_html]) : Helpdesk::HTMLSanitizer.clean(attributes[nested_attribute][element_html])
          attributes[nested_attribute][element_html] =
            FDRinku.auto_link(sanitized_html, { :attr => 'rel="noreferrer"' })
          attributes[nested_attribute][element]=
            Helpdesk::HTMLSanitizer.plain(attributes[nested_attribute][element_html]).strip
        end
      end
      attributes
    end

    private

      def is_ticket_sanitizer
        (Account.current.launched?(:css_sanitizer) && ['Helpdesk::Ticket', 'Helpdesk::Note'].include?(self.class.name))
      end

  end
end
