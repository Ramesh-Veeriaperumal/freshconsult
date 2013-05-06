unless Rails.env.development?
  git_version = $redis.get("cloudfront_version")
  Jammit.instance_variable_set(:@package_path, "packages/#{git_version}")
end

CloudfrontAssetHost.configure do |config|
  config.cname = Proc.new { |source, request|
    cloudfront_cname = (Rails.env.production? ? "static%d.freshdesk.com" : "static%d.freshpo.com")
    cloudfront_distribution = (Rails.env.production? ? "d3o14s01j0qbic.cloudfront.net" : "d3thwd261m1b0m.cloudfront.net")
    params = request.parameters
    if params['format'] == 'widget'
      asset_hostname = asset_hostname_ssl = Rails.env.production? ? "asset.freshdesk.com" : "localhost:3000"
    else
      asset_hostname = (cloudfront_cname =~ /%d/) ? cloudfront_cname % (rand(3)+2) : cloudfront_cname.to_s
      asset_hostname_ssl = cloudfront_distribution
    end
    asset_host_url = "http://#{asset_hostname}"
    if request.protocol == "https://"
      asset_host_url = "https://#{asset_hostname_ssl}"
    end
    asset_host_url
  }
  config.bucket           = ( Rails.env.production? ? "freshdeskstatic" : "fd-static" )
  config.key_prefix       = "#{Rails.env}"
  config.plain_prefix     = "plain"
  config.image_extensions = %w(jpg jpeg gif png ico)
  config.asset_dirs       = %w(packages)
  config.exclude_pattern  = /psd|images\/sprite-images|images\/cdn-ignored/
  config.s3_config        = "#{RAILS_ROOT}/config/s3_static_files.yml"
  config.s3_logging       = true
  config.gzip             = true  
  config.gzip_extensions  = %w(js css)
  config.gzip_prefix      = "gz"
  config.enabled          = true unless Rails.env.development?
  config.rewrite_css_path = false
end