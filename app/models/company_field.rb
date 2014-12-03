class CompanyField < ActiveRecord::Base

  self.table_name= "company_fields"

  serialize :field_options

  belongs_to_account

  DEFAULT_FIELD_PROPS = {
    :default_name           => { :type => 1, :dom_type => :text, :label => 'company.name' },
    :default_description    => { :type => 2, :dom_type => :paragraph, :label => 'description', :dom_placeholder =>  'company.info8' },
    :default_note           => { :type => 3, :dom_type => :paragraph, :label => 'company.notes', :dom_placeholder => 'company.info5' },
    :default_domain_name    => { :type => 4, :dom_type => :text, :label => 'company.info2', :bottom_note => 'company.info9' }
  }

end