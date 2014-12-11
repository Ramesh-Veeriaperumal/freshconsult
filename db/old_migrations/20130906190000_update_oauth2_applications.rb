class UpdateOauth2Applications < ActiveRecord::Migration

  shard :none

  def self.up
    Sharding.execute_on_all_shards do
      result = false
      salesforce_app = Integrations::Application.find_by_name 'salesforce'
      if salesforce_app
        salesforce_app.options[:oauth_url] = "/auth/salesforce?origin=id%3D{{account_id}}"
        result = salesforce_app.save
      end
      puts "Updating Salesforce       :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      nimble_app = Integrations::Application.find_by_name 'nimble'
      if nimble_app
        nimble_app.options[:oauth_url] = "/auth/nimble?origin=id%3D{{account_id}}"
        result = nimble_app.save
      end
      puts "Updating Nimble           :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      google_calendar_app = Integrations::Application.find_by_name 'google_calendar'
      if google_calendar_app
        google_calendar_app.options[:oauth_url] = "/auth/google_oauth2?origin=id%3D{{account_id}}%26app_name%3Dgoogle_calendar"
        result = google_calendar_app.save
      end
      puts "Updating Google Calendar  :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      surveymonkey_app = Integrations::Application.find_by_name 'surveymonkey'
      if surveymonkey_app
        surveymonkey_app.options[:oauth_url] = "/auth/surveymonkey?origin=id%3D{{account_id}}"
        result = surveymonkey_app.save
      end
      puts "Updating SurveyMonkey     :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      mailchimp = Integrations::Application.find_by_name 'mailchimp'
      if mailchimp
        mailchimp.options[:oauth_url] = "/auth/mailchimp?origin=id%3D{{account_id}}"
        result = mailchimp.save
      end
      puts "Updating MailChimp        :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      constant_contact = Integrations::Application.find_by_name 'constantcontact'
      if constant_contact
        constant_contact.options[:oauth_url] = "/auth/constantcontact?origin=id%3D{{account_id}}"
        result = constant_contact.save
      end
      puts "Updating ConstantContact  :::   #{result ? 'OK' : 'FAILED'}"
    end
  end

  def self.down
    Sharding.execute_on_all_shards do
      result = false
      salesforce_app = Integrations::Application.find_by_name 'salesforce'
      if salesforce_app
        salesforce_app.options[:oauth_url] = "/auth/salesforce?origin={{portal_id}}"
        result = salesforce_app.save
      end
      puts "Reverting Salesforce       :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      nimble_app = Integrations::Application.find_by_name 'nimble'
      if nimble_app
        nimble_app.options[:oauth_url] = "/auth/nimble?origin={{portal_id}}"
        result = nimble_app.save
      end
      puts "Reverting Nimble           :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      google_calendar_app = Integrations::Application.find_by_name 'google_calendar'
      if google_calendar_app
        google_calendar_app.options[:oauth_url] = "/auth/google_oauth2?origin=pid%3D{{portal_id}}%26app_name%3Dgoogle_calendar"
        result = google_calendar_app.save
      end
      puts "Reverting Google Calendar  :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      surveymonkey_app = Integrations::Application.find_by_name 'surveymonkey'
      if surveymonkey_app
        surveymonkey_app.options[:oauth_url] = "/auth/surveymonkey?origin={{portal_id}}"
        result = surveymonkey_app.save
      end
      puts "Reverting SurveyMonkey     :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      mailchimp = Integrations::Application.find_by_name 'mailchimp'
      if mailchimp
        mailchimp.options[:oauth_url] = "/auth/mailchimp?origin={{portal_id}}"
        result = mailchimp.save
      end
      puts "Reverting MailChimp        :::   #{result ? 'OK' : 'FAILED'}"

      result = false
      constant_contact = Integrations::Application.find_by_name 'constantcontact'
      if constant_contact
        constant_contact.options[:oauth_url] = "/auth/constantcontact?origin={{portal_id}}"
        result = constant_contact.save
      end
      puts "Reverting ConstantContact  :::   #{result ? 'OK' : 'FAILED'}"
    end
  end
end
