# encoding: utf-8
class CompanyDomain < ActiveRecord::Base

  belongs_to_account
  belongs_to :company

  before_validation :downcase_and_strip

  validates_presence_of :domain
  validates_uniqueness_of :domain, :scope => [:account_id, :company_id] #remove company_id in phase-II

  private

    def downcase_and_strip
      self.domain = domain.downcase.strip if domain
    end 
end
