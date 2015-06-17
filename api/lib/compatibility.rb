# For configuration(like perform_caching, allow_forgery_protection) to be loaded for action controller metal, there are methods originally in base needs to be declared.
# So that lazy load hooks will set the configuration accordingly. Suggested bt rails-api
module Compatibility
  def cache_store; end

  def cache_store=(*); end

  def assets_dir=(*); end

  def javascripts_dir=(*); end

  def stylesheets_dir=(*); end

  def page_cache_directory=(*); end

  def asset_path=(*); end

  def asset_host=(*); end

  def relative_url_root=(*); end

  def perform_caching=(*); end

  def helpers_path=(*); end

  def allow_forgery_protection=(*); end

  def helper_method(*); end

  def helper(*); end
end
