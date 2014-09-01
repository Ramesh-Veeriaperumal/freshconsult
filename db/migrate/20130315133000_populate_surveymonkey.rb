class PopulateSurveymonkey < ActiveRecord::Migration

@app_name = "surveymonkey"
shard :none
  def self.up
    app = Integrations::Application.new
    app.name = @app_name
    app.display_name = "integrations.surveymonkey.label"  
    app.description = "integrations.surveymonkey.desc"
    app.listing_order = 21
    app.options = {
        :keys_order => [:settings], 
        :direct_install => true,
        :settings => { 
          :partial => 'integrations/surveymonkey/edit',
          :type => :custom,
          :required => false,
          :label => 'integrations.surveymonkey.form.survey_settings',
          :info => 'integrations.surveymonkey.form.survey_settings_info'
  			},
        :configurable => true,
        :oauth_url => "/auth/surveymonkey?origin={{portal_id}}",
        :before_save => {
          :clazz => 'Integrations::SurveyMonkey',
          :method => 'sanitize_survey_text'
        },
        :after_save => {
          :clazz => 'Integrations::SurveyMonkey',
          :method => 'delete_cached_status'
        },
        :after_destroy => {
          :clazz => 'Integrations::SurveyMonkey',
          :method => 'delete_cached_status'
        }
    }
    app.save!
    puts "INSERTED surveymonkey APP ID #{app.id}"
  end

  def self.down
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end
