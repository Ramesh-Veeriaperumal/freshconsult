class Community::Sitemap
  
  URL_STRUCTURE = {
    :home => '/support/home',
    :solution_home => '/support/solutions',
    :solution_category => '/support/solutions',
    :solution_folder => '/support/solutions/folders',
    :solution_article => '/support/solutions/articles',
    :discussion_home => '/support/discussions',
    :discussion_category => '/support/discussions',
    :discussion_forum => '/support/discussions/forums',
    :discussion_topic => '/support/discussions/topics',
  }

  SOLUTION = ['category', 'folder', 'article']
  FORUM = ['category', 'forum', 'topic']
  CHANGE_FREQ = "always"
  ATTRIBUTES = { :xmlns => "http://www.sitemaps.org/schemas/sitemap/0.9" , "xmlns:xhtml" => "http://www.w3.org/1999/xhtml" }

  def initialize(portal)
    @portal = portal
    @domain = "#{portal.url_protocol}://#{portal.host}"
    @portal_languages = @portal.account.all_portal_languages
    @lastmod = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S%:z")
    @urls = []
  end

  def build
    @portal.clear_sitemap_cache 
    generate_urls
    xml = Builder::XmlMarkup.new(:indent => 2)
    xml.instruct!
    xml.urlset ATTRIBUTES do
      @urls.each do |url|
        xml << url.to_xml
      end
    end
  end

  private

  def level(num)
    (0.8**num).round(3)
  end

  def generate_urls
    home_url
    solution_urls
    discussion_urls
  end

  def static_url_for(structure_key, lang = nil, param = nil)
    "#{@domain}#{'/' + lang if (@portal.multilingual? && lang.present?)}#{structure_key}#{'/' + param.to_s if param.present?}"
  end

  def url_opt(loc, priority, lastmod, alternates = nil)
    {
      :loc => loc,
      :lastmod => lastmod,
      :changefreq => CHANGE_FREQ,
      :priority => priority,
      :alternates => alternates
    }
  end

  def home_url 
    @portal_languages.each do |loc_lang|
      loc = static_url_for(URL_STRUCTURE[:home],loc_lang)
      alternates = @portal_languages.size > 1 ? find_alternates(@portal_languages, :home) : []
      @urls.push(Community::Sitemap::Url.new(url_opt(loc, level(0), @lastmod,  alternates)))
    end
  end

  def solution_urls
    return unless solutions_present?
    solution_home
    solution_category_urls(solution_category_metas)
    solution_folder_urls(solution_folder_metas)
    solution_article_urls(@portal.account.solution_article_meta.for_portal(@portal))
  end

  def solutions_present?
    Account.current.features?(:open_solutions) && solution_folder_metas.present? && solution_languages.present?
  end

  def solution_languages
    @solution_languages ||= begin
      sol_lang = []
      solution_category_metas.each do |category_meta|
        category_meta.solution_categories.each {|c| sol_lang.push(c.language_code) unless sol_lang.include? c.language_code }
      end
      sol_lang & @portal_languages
    end
  end

  def solution_folder_metas
    @solution_folder_metas ||= @portal.account.solution_folder_meta.public_folders(solution_category_metas.map(&:id)).preload(:solution_folders)
  end

  def solution_category_metas
    @solution_category_metas ||= @portal.solution_category_meta.where(:is_default => false)
  end

  def solution_home
    solution_languages.each do |loc_lang|
      loc = static_url_for(URL_STRUCTURE[:solution_home],loc_lang)
      alternates = solution_languages.size > 1 ? find_alternates(solution_languages, :solution_home) : []
      @urls.push(Community::Sitemap::Url.new(url_opt(loc, level(1), @lastmod, alternates)))
    end
  end

  SOLUTION.each do |type|
    define_method "solution_#{type}_urls" do |metas|
      metas.find_each do |meta|
        versions = (type == "article") ? meta.children.visible : meta.children
        versions.select! { |v| solution_languages.include?(v.language_code) }
        next unless versions.size > 0 
        priority = level(SOLUTION.index(type) + 1)
        versions.each do |item|
          loc = static_url_for(URL_STRUCTURE[("solution_"+type).to_sym], item.language_code, item.to_param)
          lastmod = type == "article" ? item.modified_at.strftime("%Y-%m-%dT%H:%M:%S%:z") : @lastmod
          alternates = versions.size > 1 ? find_alternates(versions, ("solution_"+type).to_sym) : []

          @urls.push(Community::Sitemap::Url.new(
            url_opt(loc, priority, lastmod, alternates))
          )
        end
      end
    end
  end

  def find_alternates(versions, key)
    homes = [:home, :solution_home].include? key
    versions.collect do |item|
      lang =  homes ? item : item.language_code
      param = homes ? nil : item.to_param
      {
        :href => static_url_for(URL_STRUCTURE[key], lang, param),
        :hreflang => lang 
      } 
    end
  end

  def discussion_urls
    return unless discussion_present?
    discussion_home
    category_urls(@portal.forum_categories)
    forum_urls(portal_forums)
    topic_urls(portal_forums.map(&:portal_topics).flatten)
  end

  def discussion_present?
    Account.current.features?(:forums) &&
      Account.current.open_forums_enabled? &&
      !Account.current.hide_portal_forums_enabled? &&
      portal_forums.exists?
  end

  def portal_forums
    @portal_forums ||= @portal.portal_forums.where(:forum_visibility => 1).preload(:portal_topics)
  end

  def discussion_home 
    priority = level(1)
    loc = static_url_for(URL_STRUCTURE[:discussion_home])
    @urls.push(Community::Sitemap::Url.new(url_opt(loc, priority, @lastmod)))
  end

  FORUM.each do |type|
    define_method "#{type}_urls" do |objs|
      structure_key = URL_STRUCTURE[("discussion_" + type).to_sym]
      priority = level(FORUM.index(type) + 1)
      objs.each do |obj|
        lastmod = type == "topic" ? obj.replied_at.strftime("%Y-%m-%dT%H:%M:%S%:z") : @lastmod
        @urls.push(Community::Sitemap::Url.new(
          url_opt(static_url_for(structure_key, nil, obj.id.to_s), priority, lastmod))
        )
      end
    end
  end

  class Url
    def initialize(opt={})
      @opt = opt
    end

    def to_xml
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.url do
        [:loc, :lastmod, :changefreq, :priority].each do |key|
          xml.__send__(key, @opt[key]) unless @opt[key].nil?
        end
        (@opt[:alternates] || []).each do |alternate|
          attributes = { 
            :rel => "alternate", 
            :hreflang => alternate[:hreflang].to_s, 
            :href => alternate[:href].to_s
          }
          xml.xhtml :link, attributes
        end
      end
    end
  end
end
