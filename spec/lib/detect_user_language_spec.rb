# encoding: utf-8
require 'spec_helper'

TEST_LANGUAGES = {
  :es => "Feliz cumpleaños!",
  :'ja-JP' => "みなさんにハッピーホリデー！",
  :'ta-IN' => "இனிய புத்தாண்டு நல் வாழ்த்துக்கள்!"
}

class FakeResponse
  attr :body
  def initialize body
    @body = body
  end
end

RSpec.describe Helpdesk::DetectUserLanguage do

  before(:all) do
    @new_user = @account.users.create(FactoryGirl.attributes_for(:user, :email => Faker::Internet.email))
  end
  
  it "should set the detected language if we support translations for that language" do
    stub_google_api("es")
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:es])
    @new_user.language.to_sym.should be_eql(:es)
    Google::APIClient.any_instance.unstub(:execute)
  end

  it "should set the detected hyphenated language if we support translations for that language" do
    stub_google_api("ja-JP")
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:'ja-JP'])
    @new_user.language.to_sym.should be_eql(:'ja-JP')
    Google::APIClient.any_instance.unstub(:execute)
  end

  it "should set the account's default language if we do not support translation for that language" do
    stub_google_api("Na'vi")    
    @new_user.update_column(:language, "es")
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:"Na'vi"])
    @new_user.language.to_sym.should be_eql(@account.language.to_sym)
    Google::APIClient.any_instance.unstub(:execute)
  end

  it "should set the account's default language if any exception arises" do
    Google::APIClient.any_instance.stubs(:execute).raises(StandardError)
    @new_user.update_column(:language, "es")
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:"Na'vi"])
    @new_user.language.to_sym.should be_eql(@account.language.to_sym)
    Google::APIClient.any_instance.unstub(:execute)
  end

  def stub_google_api(language)
    result = {
      "data" => {
        "detections" => [
          [
            {
              "language"   => language,
              "isReliable" => false,
              "confidence" => 0.13102010
            }
          ]
        ]
      }
    }
    Google::APIClient.any_instance.stubs(:execute).returns(FakeResponse.new(result.to_json))
  end

end
