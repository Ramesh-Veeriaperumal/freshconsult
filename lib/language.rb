class Language
	attr_accessor :code, :id, :name

	def initialize(args)
		args.each do |k,v|
			self.safe_send("#{k.to_s}=",v)
		end
	end

	LANGUAGES = (Languages::Constants::AVAILABLE_LOCALES_WITH_ID.each.inject([]) do |arr, (code, lang)| 
					# added code.dup as string keys of a hash are frozen by default
					arr << self.new(:code => code.dup, :id => lang.first, 
									:name => lang.last) 
					arr
				end)
	TEST_LANGUAGES = [:"test-ui", :"long-text"].freeze

	PROD_LANGUAGES = LANGUAGES.reject { |x| TEST_LANGUAGES.map(&:to_s).include?(x.code.to_s) }
	
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

	def short_code
		code[0..1]
	end
	
	def to_liquid
		@language_drop ||= LanguageDrop.new self
	end

	class << self

		def all
			LANGUAGES
		end

		def all_codes
			all.map(&:code)
		end

		def all_keys
			all.map(&:to_key)
		end
		
		def all_ids
			all.map(&:id)
		end

		def find(id)
			all.detect { |lang| lang.id == id.to_i}
		end

		def find_by_code(code)
			all.detect { |lang| lang.code == strip_bom(code)}
		end

		def find_by_codes(codes)
			codes.map!{ |x| strip_bom(x) }
			all.select { |lang| codes.include?(lang.code) }
		end

		def find_by_name(name)
			all.detect { |lang| lang.name == name.to_s}
		end

		def find_by_key(key)
			all.detect { |lang| lang.to_key == key.to_s}
		end

		def reset_current
			Thread.current[:language] = nil
		end

		def set_current(params={})
			[:url, :user, :browser, :portal, :primary].each do |meth|
				language = safe_send("fetch_from_#{meth}", params)
				Thread.current[:language] = language if Account.current.valid_portal_language?(language)
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

    def fetch_from_browser(params)
      code = Languages::Constants::LANGUAGE_ALT_CODE[params[:request_language]] || params[:request_language]
      Language.find_by_code(code)
    end

		def fetch_from_portal params
			Language.find_by_code(Portal.current.language) if Portal.current
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
			
			# If Agent, check if the language is in Account-Supportedlist
			# If user, check in portal list
		end

		def for_user(user)
			(Account.current.multilingual? && Account.current.supported_languages.include?(user.language)) ? 
						find_by_code(user.language) : for_current_account
		end
		
		def default
			find_by_code("en")
		end

		private

		def strip_bom(code)
			code.to_s.gsub("\xEF\xBB\xBF".force_encoding("UTF-8"), '')
		end
	end
end
