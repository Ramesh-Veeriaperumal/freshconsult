class PopulateSeoshop < ActiveRecord::Migration
	shard :all

  def self.up

  	seoshop = Integrations::Application.create(
        :name => "seoshop",
        :display_name => "integrations.seoshop.label",
        :description => "integrations.seoshop.desc",
        :listing_order => 25,
        :options => {
	        :keys_order => [:api_key, :api_secret, :language], 
	        :api_key => {  :type => :text,
	        				       :required => true,
	        				       :label => "integrations.seoshop.form.api_key",
	        				       :info => "integrations.seoshop.form.api_key_info"
	        			      }, 
	        :api_secret => { :type => :text, 
	        				         :required  => true, 
	        				         :label => "integrations.seoshop.form.api_secret",
	        				         :info => "integrations.seoshop.form.api_secret_info"
	        			          },
	        :language => { :type => :dropdown,
	        				       :choices => [
                                        ["integrations.seoshop.form.bg", "bg"],
                                        ["integrations.seoshop.form.da", "da"],
                                        ["integrations.seoshop.form.de", "de"],
                                        ["integrations.seoshop.form.en", "en"],
                                        ["integrations.seoshop.form.nl", "nl"],
                                        ["integrations.seoshop.form.fr", "fr"],
                                        ["integrations.seoshop.form.el", "el"],
                                        ["integrations.seoshop.form.it", "it"],
                                        ["integrations.seoshop.form.fr", "fr"],
                                        ["integrations.seoshop.form.nor", "\'no\'"],
                                        ["integrations.seoshop.form.pt", "pt"],
                                        ["integrations.seoshop.form.pl", "pl"],
                                        ["integrations.seoshop.form.ru", "ru"],
                                        ["integrations.seoshop.form.es", "es"],
                                        ["integrations.seoshop.form.sv", "sv"],
                                        ["integrations.seoshop.form.tr", "tr"]
                                    ],
	                      :required => true,
	                      :default_value => "en",
	                      :label => "integrations.seoshop.form.language"
	              }
    	},
        :application_type => "seoshop",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    seoshop.save
  end

  def self.down
  	Integrations::Application.find(:first, :conditions => {:name => "seoshop"}).delete
  end
end
