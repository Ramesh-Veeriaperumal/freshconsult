class Language

	AVAILABLE_LOCALES_WITH_ID = YAML::load(ERB.new(File.read("#{Rails.root}/config/languages.yml")).result)

	attr_accessor :code, :id, :name

	def initialize(args)
		args.each do |k,v|
			self.send("#{k.to_s}=",v)
		end
	end

	def self.all
		languages = []
		AVAILABLE_LOCALES_WITH_ID.each do |lang, id|
			languages << self.new(:code => lang, :id => id, :name => I18n.t('meta', locale: lang)[:language_name])
		end
		languages
	end

	def self.find(id)
		all.select { |lang| lang.id == id.to_i}.first
	end

	def self.find_by_code(code)
		all.select { |lang| lang.code == code.to_s}.first
	end

	def self.find_by_name(name)
		all.select { |lang| lang.name == name.to_s}.first
	end

	def self.current
		return nil unless Portal.current || Account.current
		portal = Portal.current || Account.current.main_portal
		supported_languages = [portal.language, Account.current.supported_languages].flatten
		current_language = supported_languages.include?(I18n.locale.to_s) ? I18n.locale : portal.language 
		find_by_code(current_language)
	end
end