class Language

	AVAILABLE_LOCALES_WITH_ID = YAML::load(ERB.new(File.read("#{Rails.root}/config/languages.yml")).result)

	attr_accessor :code, :id, :name

	def initialize(args)
		args.each do |k,v|
			self.send("#{k.to_s}=",v)
		end
	end

	LANGUAGES = (AVAILABLE_LOCALES_WITH_ID.each.inject([]) do |arr, (code, lang)| 
					arr << self.new(:code => code, :id => lang.first, 
									:name => lang.last) 
					arr
				end)
	
	alias :to_s :name
	alias :to_i :id
	
	def to_sym
		code.to_sym
	end
	
	def to_key
		code.gsub('-','_').downcase
	end

	def make_current
		Thread.current[:language] = self
	end

	class << self

		def all
			LANGUAGES
		end

		def find(id)
			all.select { |lang| lang.id == id.to_i}.first
		end

		def find_by_code(code)
			all.select { |lang| lang.code == strip_bom(code.to_s).to_s}.first
		end

		def find_by_name(name)
			all.select { |lang| lang.name == name.to_s}.first
		end

		def reset_current
			Thread.current[:language] = nil
		end

		def set_current(params={})
			[:url, :user, :browser, :portal, :primary].each do |meth|
				Thread.current[:language] = send("fetch_from_#{meth}", params)
				break if Language.current?
			end
		end

		def fetch_from_url params
			if params[:url_locale] && I18n.available_locales.include?(params[:url_locale].to_sym)
				Language.find_by_code(params[:url_locale]) 
			end
		end

		def fetch_from_user params
			Language.for_current_user
		end

		def fetch_from_browser params
			Language.find_by_code(params[:request_language])
		end

		def fetch_from_portal params
			Language.find_by_code(Portal.current.language)
		end

		def fetch_from_primary params
			Language.for_current_account
		end

		def current
			Thread.current[:language]
		end

		def current?
			Thread.current[:language].present?
		end

		def current_old
			return nil unless Portal.current || Account.current
			portal = Portal.current || Account.current.main_portal
			supported_languages = [portal.language, Account.current.supported_languages].flatten
			current_language = supported_languages.include?(I18n.locale.to_s) ? I18n.locale : portal.language 
			find_by_code(current_language)
		end
		
		def for_current_account
			return nil if Account.current.blank?
			(find_by_code(Account.current.language) || default)
		end

		def for_current_user
			return nil if User.current.blank?
			(find_by_code(User.current.language) || for_current_account)
		end

		def for_user(user)
			find_by_code(user.language) || for_current_account
		end
		
		def default
			find_by_code("en")
		end

		private

		def strip_bom(code)
			code.gsub("\xEF\xBB\xBF".force_encoding("UTF-8"), '')
		end
	end
end