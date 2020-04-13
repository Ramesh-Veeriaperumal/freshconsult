module Assets::IndexPage
  module_function

  INDEX_HTML_PAGE = 'INDEX_HTML_PAGE'.freeze
  INDEX_PAGE_URI = URI(AppConfig['falcon_ui']['index_page'])
  def html_content
    Rails.cache.fetch(INDEX_HTML_PAGE, race_condition_ttl: 10.seconds, expires_in: 15.minutes) do
      Rails.logger.debug 'Cache miss for index.html page.'
      Net::HTTP.get(INDEX_PAGE_URI)
    end
  end
end
