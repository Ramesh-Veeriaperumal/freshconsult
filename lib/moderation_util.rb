  
module ModerationUtil

  include ActionDispatch::Routing::UrlFor

  EMAIL_PATTERN = /(\A.*[-A-Z0-9.'_&%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,10}).*\z)/i
  NUMBER_PATTERN = /((\+\d{1,3}(-| )?\(?\d\)?(-| )?\d{1,5})|(\(?\d{2,6}\)?))(-| )?([A-Z,0-9]{2,4})(-| )?([A-Z,0-9]{3,4})(-| )?(( x| ext)(-| )?\d{1,5}){0,1}/

  APPROVED_DOMAINS = YAML::load_file(File.join(Rails.root, 'config', 'whitelisted_link_domains.yml'))

	def is_spam?(post, request_params)
    Akismetor.spam?(akismet_params(post, request_params))
  end

  def akismet_params(post, request_params)
    {
      :key => AkismetConfig::KEY,

      :comment_type => 'forum-post'
    }.merge((request_params || {}).symbolize_keys).merge(env_params).merge(post_attrs(post))
  end

  def env_params
    (Rails.env.production? or Rails.env.staging?) ? {} : { :is_test => 1 }
  end

  def post_attrs(post)
    {
      :blog => post.account.full_url,

      :comment_author     => post.user.name,
      :comment_author_email => post.user.email,
      :comment_content    => post.body
    }
  end

  def to_be_moderated?(post)
    return true if Account.current.features_included?(:moderate_all_posts)

    Account.current.features_included?(:moderate_posts_with_links) && suspicious?(post)
  end

  def suspicious?(post)
    content = post_content(post)
    email_or_phone?(content.gsub(URI.regexp,'')) || unsafe_links?(content)
  end

  def post_content(post)
    content = post.body_html.clone
    content.prepend "#{post.topic.title} " if post.topic.new_record? or post.original_post?
    content
  end

  def email_or_phone?(content)
    content.scan(NUMBER_PATTERN).present? || content.scan(EMAIL_PATTERN).present?
  end

  def unsafe_links?(content)
    links = URI.extract(content)
    links.present? && any_unsafe_link?(links, add_www(acceptable_domains))
  end

  def acceptable_domains
    APPROVED_DOMAINS | ([Account.current.full_domain] | portal_urls ).delete_if { |url| url.blank? }
  end

  def portal_urls
    Account.current.portals.map { |p| [p.portal_url, url_host(p.preferences[:logo_link])] }.flatten
  end

  def add_www(hosts)
    hosts | hosts.map{ |h| h.starts_with?('www.') ? h[4..-1] : "www.#{h}"}
  end

  def any_unsafe_link?(links, domain_list)
    links.each do |link|
      host = url_host(link)
      next if host.blank?
      return true unless domain_list.include? host
    end
    false
  end

  def url_host(url)
    begin
      return URI.parse(url).host
    rescue Exception => e
      # There can be many malformed urls being sent.
      return ""
    end
  end

end