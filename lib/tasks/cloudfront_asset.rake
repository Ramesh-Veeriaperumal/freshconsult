namespace :cloudfront_assets do
  desc "upload cloudfront uploads"

  task :compile => :environment do
    change?
    compile!
  end

  task :upload => :environment do
    change_in_assets = change?
    compile!
    upload! if change_in_assets
    puts "NO CHANGE IN assets.. So not uploading to cloudfront.
            VERSIONS are cloudfront::#{@cloudfront_version} Repo::#{@git_version}" unless change_in_assets
  end

  def change?
    @cloudfront_version = $redis_portal.get("cloudfront_version")
    git_version_command = "git log --pretty=format:%h --max-count=1 --branches=HEAD -- ./public/"
    @git_version = `#{git_version_command}`
    @git_version.gsub!("\n","")
    puts "VERSIONS are cloudfront::#{@cloudfront_version} Repo::#{@git_version}"
    Jammit.instance_variable_set(:@package_path, "packages/#{@git_version}") if CloudfrontAssetHost.enabled
    (@cloudfront_version.blank? || !@cloudfront_version.eql?(@git_version))
  end

  def compile!
    puts "::::Compile started:::#{Time.now}"
    sh "bundle exec compass compile -e production"
    sh "bundle exec jammit --output #{Rails.root}/public/#{Jammit.package_path}"
    sh "sudo rm -rf #{Rails.root}/public/#{Jammit.package_path}/images"
    sh "sudo rm -rf #{Rails.root}/public/#{Jammit.package_path}/fonts"
    sh "mkdir #{Rails.root}/public/#{Jammit.package_path}/images/"
    sh "mkdir #{Rails.root}/public/#{Jammit.package_path}/fonts/"
    sh "mkdir #{Rails.root}/public/#{Jammit.package_path}/images/sprites"
    sh "cp -r #{Rails.root}/public/images/sprites/ #{Rails.root}/public/#{Jammit.package_path}/images/"
    sh "cp -r #{Rails.root}/public/fonts/ #{Rails.root}/public/#{Jammit.package_path}/"
    puts "::::Compile ended:::#{Time.now}"
  end

  def upload!
    puts "::::upload started:::#{Time.now}"
    CloudfrontAssetHost::Uploader.upload!(:verbose => true,
      :dryrun =>  !CloudfrontAssetHost.enabled,
      :force_write => true)
    $redis_portal.set("cloudfront_version",@git_version)
    puts "::::upload started:::#{Time.now}"
  end

end
