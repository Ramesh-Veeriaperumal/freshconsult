module Sync::Transformer::InlineAttachmentUtil
  ONE_HOP_URL_IDENTIFIER = (AppConfig[:attachment][Rails.env].with_indifferent_access[:domain][PodConfig['CURRENT_POD']]).to_s

  def inline_attachment_data(content, source_account)
    attachment_ids = []
    inline_urls = []
    parsed_content = Nokogiri::HTML(content)
    parsed_content.xpath('//img').each do |inline|
      src = inline.get_attribute('src')
      next unless src && src.include?(ONE_HOP_URL_IDENTIFIER)
      token = Rack::Utils.parse_query(URI(src).query)['token']
      decoded_hash = decode_hash(token, source_account)
      next unless decoded_hash
      attachment_ids << decoded_hash[:id] if decoded_hash[:id]
      inline_urls << src
    end
    [attachment_ids, inline_urls]
  end

  def decode_hash(token, source_account)
    JWT.decode(token, source_account.attachment_secret).first.with_indifferent_access
    rescue StandardError => e
      Rails.logger.info "JWT signature validation with existing account token: #{e.message}"
      return nil
  end
end