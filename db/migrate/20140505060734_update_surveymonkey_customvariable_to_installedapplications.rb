class UpdateSurveymonkeyCustomvariableToInstalledapplications < ActiveRecord::Migration
	shard :all

  def self.up
  	
      result = false
      surveymonkey_app = Integrations::InstalledApplication.find_by_application_id(21)
      if surveymonkey_app
        survey_inputs = surveymonkey_app.configs[:inputs]
        survey_inputs.merge({"custom_variable" => "false"})
        result = surveymonkey_app.save
      end
      puts "Updating SurveyMonkey     :::   #{result ? 'PASSED' : 'FAILED'}"
  
  end

  def self.down
  end
end
