class DkimCategoryChangeActivity < ActiveRecord::Base
  belongs_to_account
  belongs_to :outgoing_email_domain_category

  serialize :details, Hash
end
