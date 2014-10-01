# encoding: utf-8

require 'spec_helper'

TEST_LANGUAGES = {
  :es => "Feliz cumpleaños!",
  :'ja-JP' => "みなさんにハッピーホリデー！",
  :'ta-IN' => "இனிய புத்தாண்டு நல் வாழ்த்துக்கள்!"
}

RSpec.describe Helpdesk::DetectUserLanguage do

  before(:all) do
    @new_user = @account.users.create(FactoryGirl.attributes_for(:user, :email => Faker::Internet.email))
  end
  
  it "should set the detected language if we support translations for that language" do
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:es])
    @new_user.language.to_sym.should be_eql(:es)
  end

  it "should set the detected hyphenated language if we support translations for that language" do
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:'ja-JP'])
    @new_user.language.to_sym.should be_eql(:'ja-JP')
  end

  it "should set the account's default language if we do not support translation for that language" do
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:"Na'vi"])
    @new_user.language.to_sym.should be_eql(@account.language.to_sym)
  end

  it "should set the account's default language if any exception arises" do
    Google::APIClient.any_instance.stubs(:execute).raises(StandardError)
    Helpdesk::DetectUserLanguage.set_user_language!(@new_user, TEST_LANGUAGES[:"Na'vi"])
    @new_user.language.to_sym.should be_eql(@account.language.to_sym)
    Google::APIClient.any_instance.unstub(:execute)
  end

end
