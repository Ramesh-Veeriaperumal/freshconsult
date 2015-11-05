require 'spec_helper'

include Solution::UrlSterilize
include Rails.application.routes.url_helpers

describe Solution::UrlSterilize do

  titles_and_paths = {
    "đính kèm của bạn vượt quá 15 MB. Hãy thay đổi trước khi bạn tiến hành" => "đính-kèm-của-bạn-vượt-quá-15-mb-hãy-thay-đổi-trước-khi-bạn-tiến-hành",
    "devam etmek için lütfen bir plan seçiniz" => "devam-etmek-icin-lütfen-bir-plan-seciniz",
    "Cần hướng dẫn cài đặt gói VPN Server trên NAS" => "cần-hướng-dẫn-cài-đặt-gói-vpn-server-trên-nas",
    "Wie funktionieren die „Bester in...“-Banner?" => "wie-funktionieren-die-bester-in-banner-",
    "überprüfen wir \"nur\" Gibt es eine Möglichkeit, weitere Domainendungen" => "überprüfen-wir-nur-gibt-es-eine-möglichkeit-weitere-domainendungen",
    "¿Qué es lo que tienes que una buena palabra clave?" => "-qué-es-lo-que-tienes-que-una-buena-palabra-clave-",
    "SportsはNBAフューチャーを提供していますか？" => "sportsはnbaフューチャーを提供していますか-",
    "Какой лимит действует по тизерам на матчи NFL?" => "Какой-лимит-действует-по-тизерам-на-матчи-nfl-",
    "≤≥÷…æ“‘«¡™£¢∞§¶•ªº–≠⁄€‹›ﬁﬂ‡°·‚—±¯˘¿ÚÆ”’»" => "-ae-uae-",
    "And special å∂ßAdhsg ¨ˆ¥ø∑´˜√¬∆˚„Ï´ÏÅÎÍÅÏ€ﬁ›‹ﬂ›‡ﬂ“π" => "and-special-a-adhsg-i-iaiiai-pi",
    "However impossible  ≥÷≤…æ“‘«¯¿˘ÆÚ”’»~+_-)(*&^@%$$!&@*)" => "however-impossible-ae-aeu-" 
  }

  self.use_transactional_fixtures = false

  before(:all) do
    @test_category = create_category( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1, :category_id => @test_category.id } )

    @special_characters = "≤≥÷…æ“‘«¡™£¢∞§¶•ªº≠⁄€‹›ﬁﬂ‡°·‚±¯˘¿Ú¿”Æ”’»¨ˆ¥ø∑´˜√¬∆˚„Ï´ÏÅÎÍÅÏ€ﬁ›‹ﬂ›‡ﬂ“π+)(*&^@%$$&@*)"
    unicode_title = Faker::Lorem.sentence(1) + @special_characters

    @special_article = create_article({
      :title => "#{unicode_title}",
      :description => "#{Faker::Lorem.sentence(3)}", 
      :folder_id => @test_folder.id,
      :user_id => @agent.id, 
      :status => "2", 
      :art_type => "1" })
  end

  describe "dangerous characters" do
  
    it "should be removed" do
      @special_characters.split('').each do |char|
        expect(sterilize(@special_characters)).not_to include(char)
      end
    end

    it "should be removed from urls" do
      @special_characters.split('').each do |char|
        expect(solution_article_path(@special_article)).not_to include(char)
        expect(support_solutions_article_path(@special_article)).not_to include(char)
      end
    end
  end

  describe "ascii characters" do

    it "should be replaced with equivalents" do
      unicode_char_hash = Hash[@special_characters.split('').map {|c| [get_unicode(c), c] }]
      replace_hash = Solution::UrlSterilize::BLACKLIST[:replace_equivalent]
      (unicode_char_hash.keys & replace_hash.keys).each do |char|
        expect(sterilize(@special_characters)).not_to include(unicode_char_hash[char])
        expect(sterilize(@special_characters)).to include(replace_hash[char])
      end
    end

    it "should be replaced with equivalents in urls" do
      titles_and_paths.each do |title, url|
        @special_article.update_attributes(:title => title)
        expect(solution_article_path(@special_article)).to include("#{@special_article.id}-#{url_encode(url)}")
        expect(support_solutions_article_path(@special_article)).to include("#{@special_article.id}-#{url_encode(url)}")
      end
    end
  end

  after(:all) do
    @test_category.destroy
  end

end