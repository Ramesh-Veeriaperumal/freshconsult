class ContactField < ActiveRecord::Base

  serialize :field_options

  belongs_to_account
  
  DEFAULT_FIELD_PROPS = {
    :default_name           => { :type => 1, :dom_type => :text },
    :default_job_title      => { :type => 2, :dom_type => :text},
    :default_email          => { :type => 3, :dom_type => :email },
    :default_phone          => { :type => 4, :dom_type => :phone_number},
    :default_mobile         => { :type => 5, :dom_type => :phone_number },
    :default_twitter_id     => { :type => 6, :dom_type => :text},
    :default_company_name   => { :type => 7, :dom_type => :text},
    :default_client_manager => { :type => 8, :dom_type => :checkbox},
    :default_address        => { :type => 9, :dom_type => :paragraph},
    :default_time_zone      => { :type => 10, :dom_type => :dropdown },
    :default_language       => { :type => 11, :dom_type => :dropdown },
    :default_tag_names      => { :type => 12, :dom_type => :text},
    :default_description    => { :type => 13, :dom_type => :paragraph,
                                 :dom_placeholder => :'example - LA Lakers fan etc.' }
  }

end
