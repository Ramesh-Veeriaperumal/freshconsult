class Workers::Community::CheckForSpam
  extend Resque::AroundPerform

	include ActionController::UrlWriter

  @queue = 'check_for_spam'

  EMAIL_PATTERN = /(\A.*[-A-Z0-9.'_&%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,10}).*\z)/i
  NUMBER_PATTERN = /((\+\d{1,3}(-| )?\(?\d\)?(-| )?\d{1,5})|(\(?\d{2,6}\)?))(-| )?([A-Z,0-9]{2,4})(-| )?([A-Z,0-9]{3,4})(-| )?(( x| ext)(-| )?\d{1,5}){0,1}/

  APPROVED_DOMAINS = YAML::load_file(File.join(Rails.root, 'config', 'whitelisted_link_domains.yml'))

  class << self
	  def perform(params)
	  	params.symbolize_keys!
	  	post = build_post(params[:id])
	  	process(post, params[:request_params])
	  end

	  private

  	def build_post(post_id)
  		Account.current.posts.find(post_id)
  	end

  	def process(post, request_params)
  		post.spam = is_spam?(post, request_params)
  		post.published = !post.spam? && !to_be_moderated?(post)
  		post.save
  	end

  	def is_spam?(post, request_params)
  		Akismetor.spam?(akismet_params(post, request_params))
  	end

  	def akismet_params(post, request_params)
  		env_params = { :is_test => 1 } unless (Rails.env.production? or Rails.env.staging?)

			{
				:key => AkismetConfig::KEY,

				:comment_type => 'forum-post',

				:blog => post.account.full_url,
				:permalink => post.topic_url,

				:comment_author			=> post.user.name,
				:comment_author_email	=> post.user.email,
				:comment_content		=> post.body,
			}.merge((request_params || {}).symbolize_keys).merge(env_params || {})
		end

    def to_be_moderated?(post)
      return true if Account.current.features?(:moderate_all_posts)

      Account.current.features?(:moderate_posts_with_links) && suspicious?(post)
    end

    def suspicious?(post)
      email_or_phone?(post) || unsafe_links?(post)
    end

    def email_or_phone?(post)
      post.body_html.scan(NUMBER_PATTERN).present? || post.body_html.scan(EMAIL_PATTERN).present?
    end

    def unsafe_links?(post)
      links = URI.extract(post.body_html)
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
        next if link.blank?
        return true unless domain_list.include? url_host(link)
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
end
