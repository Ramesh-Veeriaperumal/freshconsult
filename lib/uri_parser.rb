class UriParser

  DEFAULT_URL_SCHEMES = SUPPORTED_URL_SCHEMES = %w(https http ftp).freeze
  HTTPS_URL_ONLY = %w(https).freeze
  # Compile from web_irl_regex if there is any change and use the same in client side code
  WEB_IRL_REGEX = /^(^(http|https|ftp):\/\/)(?:(?:(?:%\h\h|[!$&-.0-;=A-Z_a-z~])*)@)?(?:(([a-zA-Z0-9\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]([a-zA-Z0-9\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF\-]{0,61}[a-zA-Z0-9\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]){0,1}\.)+[a-zA-Z\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]{2,63}|((25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[0-9]))))(?:(:\d{1,5})?)(\/\S*)?$/
  PRIVATE_IRL_REGEX = /^(^(http|https|ftp):\/\/)((?:(?:%\h\h|[!$&-.0-;=A-Z_a-z~])*)@)?(192\.168\.([0-9]|[0-9]{2}|[0-2][0-5]{2})\.([0-9]|[0-9]{2}|[0-2][0-5]{2}).*)|(172\.([1][6-9]|[2][0-9]|[3][0-1])\.([0-9]|[0-9]{2}|[0-2][0-5]{2})\.([0-9]|[0-9]{2}|[0-2][0-5]{2}).*)|(10\.([0-9]|[0-9]{2}|[0-2][0-5]{2})\.([0-9]|[0-9]{2}|[0-2][0-5]{2})\.([0-9]|[0-9]{2}|[0-2][0-5]{2}).*)$/


  def initialize urls
    urls = urls.split(',') if urls.is_a? String
    @urls = urls
  end

  def valid_hosts
    hosts = @urls.collect { |url| get_host_without_www(url.strip) }
    {:hosts => hosts.uniq}
  rescue
    {:errors => I18n.t('enter_valid_domains')}
  end

  def self.valid_url?(url, schemes = DEFAULT_URL_SCHEMES)
    uri = URI.parse(url)
    uri && uri.host && schemes.include?(uri.scheme)
  rescue
    false
  end

  # according to the standard of IRl defined in https://www.ietf.org/rfc/rfc3986.txt
  # Helper method to compile WEB_IRL_REGEX
  # def self.web_irl_regex
  #   host_iri_char = 'a-zA-Z0-9\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF'
  #   iri = '[' + host_iri_char + ']([' + host_iri_char + '\-]{0,61}[' + host_iri_char + ']){0,1}'
  #   top_level_domain = 'a-zA-Z\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF'
  #   user_info = '(?:(?:(?:%\h\h|[!$&-.0-;=A-Z_a-z~])*)@)?'
  #   host_name = '(' + iri + '\.)+' + '[' + top_level_domain + ']{2,63}'
  #   ip_address = '((25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[0-9]))'
  #   '^(^(http|https|ftp)://)' + user_info + '(?:(' + host_name + '|' + ip_address + '))(?:(:\d{1,5})?)(/\S*)?$'
  # end

  def self.valid_irl?(url, include_private_ips = true)
    return false unless url
    unless include_private_ips
      return false if PRIVATE_IRL_REGEX.match(url)
    end
    WEB_IRL_REGEX.match(url) != nil
  end

  private

  def get_host_without_www(url)
    uri = URI.parse(url)
    uri = URI.parse("http://#{url}") unless uri.scheme
    host = uri.host.downcase
    host.start_with?('www.') ? host[4..-1] : host
  end
end
