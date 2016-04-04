class PopulateKnowlarity < ActiveRecord::Migration
  shard :all
  
  def up
  	knowlarity = Integrations::Application.create(
        :name => "knowlarity",
        :display_name => "integrations.knowlarity.label",
        :description => "integrations.knowlarity.desc",
        :listing_order => 34,
        :options => {:direct_install => false,:keys_order => [:knowlarity_number,:api_key,:convert_to_ticket,:add_note_as_private],
        :knowlarity_number => { :type => :text, :required => true, :label => "integrations.knowlarity.number",:info => "integrations.knowlarity.number_info"},
        :api_key => { :type => :text, :required => true, :label => "integrations.knowlarity.api_key",:info => "integrations.knowlarity.apikey_info"},
        :convert_to_ticket => {:type => :checkbox, :label => "integrations.cti.convert_to_ticket", :default_value => '1'},
        :add_note_as_private => {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'},
        :dimensions => {:width => "200px",:height => "450px"},
        :after_commit => {
          :clazz => 'Integrations::Cti',
          :method => 'clear_memcache'
        }},
        :application_type => "cti_integration",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
  end

  def down
    Integrations::Application.find_by_name("knowlarity").destroy
  end
end
