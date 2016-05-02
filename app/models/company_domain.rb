# encoding: utf-8
class CompanyDomain < ActiveRecord::Base

  belongs_to_account
  belongs_to :company

  before_validation :sanitize_domain

  validates_presence_of :domain
  validates_uniqueness_of :domain, :scope => [:account_id]

  after_commit :map_contacts_to_company, on: :create
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  private

    def sanitize_domain
      if self.domain
        self.domain.gsub!('\\','') 
        host_without_www
      end
    rescue
      errors.add(:base,"#{I18n.t('companies.valid_comapany_domain')}")      
    end 

    def host_without_www
      uri = URI.parse(self.domain)
      uri = URI.parse("http://#{self.domain}") if uri.scheme.nil?
      host = uri.host.downcase
      self.domain = host.start_with?('www.') ? host[4..-1] : host
    end 

    def map_contacts_to_company
      Users::UpdateCompanyId.perform_async({ :domain => self.domain,
                                             :company_id => self.company_id }) 
    end
end
