module InlineImagesUtil
  ONE_HOP_URL_IDENTIFIER = ((AppConfig[:attachment][Rails.env].with_indifferent_access)[:domain][PodConfig['CURRENT_POD']]).to_s
  PERMANENT_S3_URL_IDENTIFIER = Regexp.new("\/#{S3_CONFIG[:bucket]}\/data\/helpdesk\/attachments\/#{Rails.env}\/(.*?)\/original\/")

  def get_attachment_ids(content)
    attachment_ids = []
    parsed_content = Nokogiri::HTML(content)
    parsed_content.xpath('//img').each do |inline|
      src = inline.get_attribute('src')
      next unless src
      if src.include?(ONE_HOP_URL_IDENTIFIER)
        token = Rack::Utils.parse_query(URI(src).query)["token"]
        if token.blank?
          Rails.logger.debug "Token not present in One hop URL : #{src}" #To check logs. Can be removed later.
          next
        end
        decoded_hash = JWT.decode(token, Account.current.attachment_secret).first.with_indifferent_access
        attachment_ids << decoded_hash[:id] if decoded_hash[:id]
      elsif PERMANENT_S3_URL_IDENTIFIER.match(src).present? && $1.present?
        attachment_ids << $1
      end
    end
    attachment_ids.uniq
  end
end
