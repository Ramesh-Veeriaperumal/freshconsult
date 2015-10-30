class AssetLoader
	
	JS = {
		:app => 'public/javascripts/cdn/app',
		:plugins => 'public/javascripts/cdn/plugins',
		:integrations => 'public/javascripts/cdn/integrations'
	}
	
	CSS = {
		:app => 'public/src/cdn/app',
		:plugins => 'public/src/cdn/plugins'
	}
	
	MANIFEST_FILE = "#{Rails.root}/public/assets/manifest.yml"
	MANIFEST = (File.exists?(MANIFEST_FILE) ? YAML::load_file(MANIFEST_FILE) : nil)
	
	class << self
	
	def js_assets
		Rails.logger.debug "Generating JS Manifest for AssetLoader"
		{
			:app => js_app_assets(:app),
			:plugins => js_app_assets(:plugins),
			:integrations => js_app_assets(:integrations)
		}
	end
	
	def css_assets
		Rails.logger.debug "Generating CSS Manifest for AssetLoader"
		{
			:app => css_app_assets(:app),
			:plugins => css_app_assets(:plugins)
		}
	end
	
	private
	
	def to_hash(array)
		Hash[*array.map { |i| [i[2], i[1]] }.flatten]
	end
	
	def js_app_assets(scope)
		Hash[*((asset_list(JS[scope]) || []).map do |asset|
			[asset.gsub('.js', '').to_s , digest_path("cdn/#{scope}/#{asset}")]
		end).flatten]
	end
	
	
	def css_app_assets(scope)
		Hash[*((asset_list(CSS[scope]) || []).map do |asset|
			[asset.gsub('.scss', '').to_s , digest_path("cdn/#{scope}/#{asset}")]
		end).flatten]
	end
	
	def asset_list(path)
		(Rails.application.assets.entries(path).map do |path|
			filename = nil
			path.each_filename { |fn| filename = fn if accept?(fn) }
			filename
		end).compact
	end
	
	def digest_path(asset)
		MANIFEST.blank? ? Rails.application.assets.find_asset(asset).digest_path : MANIFEST[asset]
	end
	
	def accept?(filename)
		return false if filename.starts_with?('_')
		return true if filename.ends_with?('js')
		return true if filename.ends_with?('scss')
		return true if filename.ends_with?('css')
		false
	end
	
	end
end