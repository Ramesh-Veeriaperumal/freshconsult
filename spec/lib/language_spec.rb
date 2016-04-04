RSpec.describe Language do
	
	AVAILABLE_LOCALES_BY_CODE = YAML::load(ERB.new(File.read("#{Rails.root}/config/languages.yml")).result)

	it "Language objects should have the same id and name as LANGUAGE_MAPPING" do
		AVAILABLE_LOCALES_BY_CODE.keys.each do |code|
			lang_mapping = AVAILABLE_LOCALES_BY_CODE[code]
			lang_obj = Language.find_by_code(code)
			lang_mapping.first.should be_eql(lang_obj.id)
			lang_mapping.last.should be_eql(lang_obj.name)
		end
	end

	describe "testing find methods" do
		before(:each) do
			@lang_code = AVAILABLE_LOCALES_BY_CODE.keys.sample
			@lang_mapping = AVAILABLE_LOCALES_BY_CODE[@lang_code]
		end

		it "should find a language by language id" do
			check_language_integrity(Language.find(@lang_mapping.first))
		end

		it "should find a language by language name" do
			check_language_integrity(Language.find_by_name(@lang_mapping.last))
		end

		it "should find a language by language code" do
			check_language_integrity(Language.find_by_code(@lang_code))
		end

		it "should find a language by language code even if the code is a symbol" do
			check_language_integrity(Language.find_by_code(@lang_code.to_sym))
		end
	end

	def check_language_integrity(lang)
		lang.code.should be_eql(@lang_code)
		lang.name.should be_eql(@lang_mapping.last)
		lang.id.should be_eql(@lang_mapping.first) 
	end
end