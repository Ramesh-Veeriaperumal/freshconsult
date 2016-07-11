class UserCompany < ActiveRecord::Base

  self.primary_key = :id

  belongs_to_account
  belongs_to :user
  belongs_to :company

  validates_presence_of :company
  validates_uniqueness_of :company_id, :scope => [:user_id, :account_id]

  after_commit :associate_tickets, on: :create
  after_commit :update_tickets_company_id, on: :update
  after_commit :remove_tickets_company_id, :set_default_company, on: :destroy
  after_commit :update_es_index

  private
  
  # This will also update the tickets' company in reports
  def associate_tickets
    Tickets::UpdateCompanyId.perform_async({ :user_ids => user_id,
                                             :company_id => company_id }) unless contractor?
  end

  def update_tickets_company_id
    Tickets::UpdateCompanyId.perform_async({ :user_ids => user_id, :company_id => company_id, :old_company_id =>  
      previous_changes["company_id"][0] }) if previous_changes["company_id"].present?
  end

  def remove_tickets_company_id
    Tickets::UpdateCompanyId.perform_async({ :user_ids => user_id,
      :company_id => nil }) unless account.features?(:multiple_user_companies)
  end

  def set_default_company
    if default && user.user_companies.reload.present?
      uc = user.user_companies.first
      uc.update_attributes(:default => true)
      user.update_column(:customer_id, uc.company_id)
    end
  end

  def update_es_index
    return if Account.current.features_included?(:es_v2_writes) || $redis_others.sismember("DISABLE_ES_WRITES", Account.current.id)
    SearchSidekiq::IndexUpdate::UserTickets.perform_async({ :user_id => user_id }) \
      if ES_ENABLED && !contractor?
  end

  def contractor?
    user.contractor?
  end
end
