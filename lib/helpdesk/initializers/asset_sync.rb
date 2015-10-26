AssetSync.configure do |config|
  # Don't delete files from the store
  # config.existing_remote_files = 'keep'
  #
  # Increase upload performance by configuring your region
  # config.fog_region = 'eu-west-1'
  #
  # Automatically replace files with their equivalent gzip compressed version
  # config.gzip_compression = true
  #
  # Use the Rails generated 'manifest.yml' file to produce the list of files to
  # upload instead of searching the assets directory.
  # config.manifest = true
  #
  # Fail silently.  Useful for environments such as Heroku
  # config.fail_silently = true
  config.run_on_precompile = false
end

assetSyncConfig = YAML::load_file(File.join(Rails.root, 'config', 'asset_sync.yml'))[Rails.env]

$asset_sync_http_url = assetSyncConfig['asset_host_url_http']
$asset_sync_https_url = assetSyncConfig['asset_host_url_https'] 