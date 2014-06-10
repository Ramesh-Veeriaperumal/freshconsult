require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module IntegrationsHelper

def create_installed_applications(options= {})
p options.inspect
application_id = Integrations::Application.find_by_name(options[:application_name]).id
installed_application = Factory.build(:installed_application, :configs=>options[:configs],
     								:account_id =>options[:account_id],
                  					:application_id => application_id)
installed_application.save
installed_application

end

end

