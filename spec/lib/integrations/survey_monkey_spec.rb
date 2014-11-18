require 'spec_helper'
load 'spec/support/integrations_helper.rb'
load 'spec/support/ticket_helper.rb'
load 'spec/support/user_helper.rb'

RSpec.describe Integrations::SurveyMonkey do

  before(:all) do
    @ticket = create_ticket(params = {}, group = nil)
    @user = add_test_agent(@account)
    @app_name = "surveymonkey"
    @ticket.account.installed_applications.with_name('surveymonkey').destroy_all
    groups_map = {  "0" => {"survey_id" => "53833928",
                            "collector_id" => "55458745", 
                            "survey_link" => "https://www.surveymonkey.com/s/X3K937T"
                           },
                    "1" => {"survey_id" => "5283776",
                            "collector_id" => "55453899",
                            "survey_link" => "https://www.surveymonkey.com/s/M3J7Y3G"
                           }
                } #this is the new version data format

    @input_options = {:inputs => {'refresh_token' => "", 
                                  'oauth_token' => "paTBz61kMlD0mPWrsaHR3921EuYbHlBvqU0GDZQ.5nahBvB1GbdZpbh2WnOzXY4Sx3DdjRm5L63Sshs3DDbF.qtbUQgFY0b6HFlivlIWW8c=",
                                  'survey_text' => "Please take this survey to help us serve you better. It won't take more than 2 mins.",
                                  #stub data in the old db format #
                                  'survey_link' => "https://www.surveymonkey.com/s/X3K937T",
                                  'survey_id' => "53833928",
                                  'collector_id' => "55458745",
                                  # end of old data format
                                  'groups' => groups_map, # stub data for the new db format
                                  "send_while" => "1"
                                }
                    }

    @installed_application = create_installed_applications({ :configs => @input_options, :account_id => @account.id, :application_name => @app_name})
  end

  it "should have link url and text when survey is sent via specific include " do
    @input_options[:inputs]["send_while"] = 4
    @installed_application.update_attributes(:configs => @input_options)
    specific_include = true # true or flase - it is a boolean. For the survey method the passed value is true.
    reply_return = Integrations::SurveyMonkey.survey(specific_include, @ticket, @user)
    reply_return.has_key?(:link).should eql(true)
    reply_return.has_key?(:text).should eql(true)
  end

  it "should have link url and text when survey is sent via all reply " do
    @input_options[:inputs]["send_while"] = 1
    @installed_application.update_attributes(:configs => @input_options)
    specific_include = false # true or flase - it is a boolean. For the survey method the passed value is true.
    reply_return = Integrations::SurveyMonkey.survey(specific_include, @ticket, @user)
    reply_return.has_key?(:link).should eql(true)
    reply_return.has_key?(:text).should eql(true)
  end

  it "should have link url and text when survey is sent for closing a ticket " do
    notification_type = 8 # 8 => 3 is for close 2 is for closing.
    @input_options[:inputs]["send_while"] = 3
    @installed_application.update_attributes(:configs => @input_options)
    @ticket.responder = @user
    reply_return = Integrations::SurveyMonkey.survey_for_notification(notification_type, @ticket)
    reply_return.has_key?(:link).should eql(true)
    reply_return.has_key?(:text).should eql(true)
  end

  it "should have link url and text when survey is sent for resolving a ticket " do
    notification_type = 7 # 7 => 2 is for close 2 is for resolved.
    @input_options[:inputs]["send_while"] = 2
    @installed_application.update_attributes(:configs => @input_options)
    @ticket.responder = @user
    reply_return = Integrations::SurveyMonkey.survey_for_notification(notification_type, @ticket)
    reply_return.has_key?(:link).should eql(true)
    reply_return.has_key?(:text).should eql(true)
  end

  it "should show send survey check box when the configured option is allow agent to select " do
    @input_options[:inputs]["send_while"] = 4
    @installed_application.update_attributes(:configs => @input_options)
    result = Integrations::SurveyMonkey.show_surveymonkey_checkbox?(@account)
    result.should eql(true)
  end

  it "should show place holder canned response when all group option is enabled " do
    result = Integrations::SurveyMonkey::placeholder_allowed?(@account)
    result.should eql(true)
  end

  

  it "should give the link configured for all group when no group is selected" do
    # for this @ticket.group_id should not be in the @input_options group
    @ticket.group_id  = 3
    #trigger the survey request call for the reply option 
    @input_options[:inputs]["send_while"] = 4
    @installed_application.update_attributes(:configs => @input_options)
    specific_include = true # true or flase - it is a boolean. For the survey method the passed value is true.
    reply_return = Integrations::SurveyMonkey.survey(specific_include, @ticket, @user)
    reply_return[:link].should_not be_nil
  end

  it "should give the link configured for all group when the ticket doesn't have a group " do
    @ticket.group_id = nil
    @input_options[:inputs]["send_while"] = 4
    @installed_application.update_attributes(:configs => @input_options)
    specific_include = true # true or flase - it is a boolean. For the survey method the passed value is true.
    reply_return = Integrations::SurveyMonkey.survey(specific_include, @ticket, @user)
    reply_return[:link].should_not be_nil
  end

  it "should have a url for old db version format of config data " do
    @input_options[:inputs].delete "groups"
    # testing if there is a url for specific include in old db format
    @input_options[:inputs]["send_while"] = 4
    @installed_application.update_attributes(:configs => @input_options) #this will have an effect on the other examples so put it in the last since it delete the newer version of DB data.
    specific_include = true # true or flase - it is a boolean. For the survey method the passed value is true.
    reply_return = Integrations::SurveyMonkey.survey(specific_include, @ticket, @user)
    reply_return.has_key?(:link).should eql(true)
    reply_return.has_key?(:text).should eql(true)
  end
end