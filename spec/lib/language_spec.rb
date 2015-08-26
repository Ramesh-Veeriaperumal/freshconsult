RSpec.describe Language do
	
	LANGUAGE_MAPPING = {"en"=>{"language_id"=>6, "language_name"=>"English"}, "fr"=>{"language_id"=>11, "language_name"=>"French"}, "ar"=>{"language_id"=>1, "language_name"=>"Arabic"}, "ca"=>{"language_id"=>2, "language_name"=>"Catalan"}, "cs"=>{"language_id"=>3, "language_name"=>"Czech"}, "da"=>{"language_id"=>4, "language_name"=>"Danish"}, "de"=>{"language_id"=>5, "language_name"=>"German"}, "es-LA"=>{"language_id"=>7, "language_name"=>"Spanish (Latin America)"}, "es"=>{"language_id"=>8, "language_name"=>"Spanish"}, "et"=>{"language_id"=>9, "language_name"=>"Estonian"}, "fi"=>{"language_id"=>10, "language_name"=>"Finnish"}, "hu"=>{"language_id"=>12, "language_name"=>"Hungarian"}, "id"=>{"language_id"=>13, "language_name"=>"Indonesian"}, "it"=>{"language_id"=>14, "language_name"=>"Italian"}, "ja-JP"=>{"language_id"=>15, "language_name"=>"Japanese"}, "ko"=>{"language_id"=>16, "language_name"=>"Korean"}, "nb-NO"=>{"language_id"=>17, "language_name"=>"Norwegian"}, "nl"=>{"language_id"=>18, "language_name"=>"Dutch"}, "pl"=>{"language_id"=>19, "language_name"=>"Polish"}, "pt-BR"=>{"language_id"=>20, "language_name"=>"Portuguese (BR)"}, "pt-PT"=>{"language_id"=>21, "language_name"=>"Portuguese/Portugal"}, "ru-RU"=>{"language_id"=>22, "language_name"=>"Russian"}, "sk"=>{"language_id"=>23, "language_name"=>"Slovak"}, "sl"=>{"language_id"=>24, "language_name"=>"Slovenian"}, "sv-SE"=>{"language_id"=>25, "language_name"=>"Swedish"}, "tr"=>{"language_id"=>26, "language_name"=>"Turkish"}, "uk"=>{"language_id"=>29, "language_name"=>"Ukrainian"}, "vi"=>{"language_id"=>27, "language_name"=>"Vietnamese"}, "zh-CN"=>{"language_id"=>28, "language_name"=>"Chinese"}} 

	it "Language objects should have the same id and name as LANGUAGE_MAPPING" do
		Language.all.each do |lang|
			lang_mapping = LANGUAGE_MAPPING[lang.code.to_s]
			lang_mapping["language_id"].should be_eql(lang.id)
			lang_mapping["language_name"].should be_eql(lang.name)
		end
	end

	describe "testing find methods" do
		before(:each) do
			@lang_code = LANGUAGE_MAPPING.keys.sample
			@lang_mapping = LANGUAGE_MAPPING[@lang_code]
		end

		it "should find a language by language id" do
			check_language_integrity(Language.find(@lang_mapping["language_id"]))
		end

		it "should find a language by language name" do
			check_language_integrity(Language.find_by_name(@lang_mapping["language_name"]))
		end

		it "should find a language by language code" do
			check_language_integrity(Language.find_by_code(@lang_code))
		end
	end

	def check_language_integrity(lang)
		lang.code.should be_eql(@lang_code)
		lang.name.should be_eql(@lang_mapping["language_name"])
		lang.id.should be_eql(@lang_mapping["language_id"]) 
	end
end