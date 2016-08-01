namespace :ymltojson do
  task :jslang => :environment do
    languages  = %w(ar ca cs da de en es-LA es et fi fr he hu id it ja-JP ko nb-NO nl pl pt-BR pt-PT ro ru-RU sk sl sv-SE th tr uk vi zh-CN zh-TW)
    #languages  = %w(en)
    #This path need to be changed as per once requirement
    output_path="tmp"
      languages.each do |lang|
        langfilejs = output_path+"/locales/#{lang}.json"
        namespace  = lang
        langfile=YAML::load(File.open("config/locales/#{lang}.yml","r"))
        file=File.open(langfilejs,"w+")
        translations = {}
        process_hash(translations, '', langfile[lang])
        file.write(translations.to_json)
      end
  end

  def process_hash(translations, current_key, hash)
    hash.each do |new_key, value|
      combined_key = [current_key, new_key].delete_if { |k| k == '' }.join(".")
      if value.is_a?(Hash)
        process_hash(translations, combined_key, value)
      else
        translations[combined_key] = value
      end
    end
  end

end
