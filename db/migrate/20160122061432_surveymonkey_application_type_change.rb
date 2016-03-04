class SurveymonkeyApplicationTypeChange < ActiveRecord::Migration

  shard :all

  def up
    application = Integrations::Application.where(:name => 'surveymonkey', :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID).first
    application.application_type = 'surveymonkey'
    application.save!
  end

  def down
    application = Integrations::Application.where(:name => 'surveymonkey', :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID).first
    application.application_type = nil
    application.save!
  end
end
