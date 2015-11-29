module JsonPattern
  def bad_request_error_pattern(field, value, params_hash = {})
    message = ErrorConstants::ERROR_MESSAGES.key?(value.to_sym) ? ErrorConstants::ERROR_MESSAGES[value.to_sym].to_s : value.to_s
    {
      field: "#{field}",
      message: message % params_hash,
      code: ErrorConstants::API_ERROR_CODES_BY_VALUE[value] || ErrorConstants::DEFAULT_CUSTOM_CODE
    }
  end

  def too_many_request_error_pattern
    {
      message: String
    }
  end

  def invalid_json_error_pattern
    {
      code: 'invalid_json',
      message: String
    }
  end

  def un_supported_media_type_error_pattern
    {
      code: 'invalid_content_type',
      message: String
    }
  end

  def not_acceptable_error_pattern
    {
      code: 'invalid_accept_header',
      message: String
    }
  end

  def request_error_pattern(code, params_hash = {})
    message = ErrorConstants::ERROR_MESSAGES.key?(code.to_sym) ? ErrorConstants::ERROR_MESSAGES[code.to_sym].to_s : code.to_s
    {
      code: code,
      message: message % params_hash
    }
  end

  def base_error_pattern(code, params_hash = {})
    message = ErrorConstants::ERROR_MESSAGES.key?(code.to_sym) ? ErrorConstants::ERROR_MESSAGES[code.to_sym].to_s : code.to_s
    {
      message: message % params_hash
    }
  end

  def format_html(ticket, body)
    body_html = Rinku.auto_link(body) { |text| truncate(text, length: 100) }
    textilized = RedCloth.new(body_html.gsub(/\n/, '<br />'), [:hard_breaks])
    textilized.hard_breaks = true if textilized.respond_to?('hard_breaks=')
    formatted = ticket.white_list(textilized.to_html)
    html_doc = Nokogiri::HTML(formatted)
    unless html_doc.at_css('body').blank?
      html_doc.xpath('//del').each { |div|  div.name = 'span'; }
      html_doc.xpath('//p').each { |div|  div.name = 'div'; }
    end
    Rinku.auto_link(html_doc.at_css('body').inner_html, :urls)
  end
end

include JsonPattern
