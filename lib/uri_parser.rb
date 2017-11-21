class UriParser

  DEFAULT_URL_SCHEMES = SUPPORTED_URL_SCHEMES = %w(https http ftp).freeze
  HTTPS_URL_ONLY = %w(https).freeze

  def initialize urls
    urls  = urls.split(",") if urls.is_a? String
    @urls = urls
  end

  def valid_hosts
    hosts = @urls.collect{|url| get_host_without_www(url.strip)}
    {:hosts => hosts.uniq}
  rescue
    {:errors => I18n.t('enter_valid_domains')}
  end

  def self.valid_url?(url,schemes=DEFAULT_URL_SCHEMES)
    uri = URI.parse(url)
    uri && uri.host && schemes.include?(uri.scheme)
  rescue
    false
  end

  private

  def get_host_without_www(url)
    uri  = URI.parse(url)
    uri  = URI.parse("http://#{url}") if uri.scheme.nil?
    host = uri.host.downcase
    host.start_with?('www.') ? host[4..-1] : host
  end
end
