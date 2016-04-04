# For configuration(like perform_caching, allow_forgery_protection) to be loaded for action controller metal, there are methods originally in base needs to be declared.
# So that lazy load hooks will set the configuration accordingly. Suggested bt rails-api
module MetalCompatibility
  def assets_dir=(*); end

  def javascripts_dir=(*); end

  def stylesheets_dir=(*); end

  def asset_path=(*); end

  def asset_host=(*); end

  def relative_url_root=(*); end

  def allow_forgery_protection=(*); end
end
