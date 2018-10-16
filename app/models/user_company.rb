class UserCompany < ActiveRecord::Base

  self.primary_key = :id

  belongs_to_account
  belongs_to :user
  belongs_to :company

  validates_presence_of :company
  validates_uniqueness_of :company_id, :scope => [:user_id, :account_id]

  after_commit :associate_tickets, on: :create
  after_commit :remove_tickets_company_id, :set_default_company, on: :destroy
  after_commit :update_es_index

  def self.has_multiple_companies?
    select(:id).group(:user_id).having("count(user_id) > 1").exists?
  end

  private

  def associate_tickets
    Tickets::UpdateCompanyId.perform_async({ :user_ids => user_id,
                                             :company_id => company_id }) unless contractor?
  end

  def remove_tickets_company_id
    # Tickets::UpdateCompanyId.perform_async({ :user_ids => user_id,
    #   :company_id => nil }) unless account.multiple_user_companies_enabled?
  end

  def set_default_company
    if default && user.user_companies.reload.present?
      uc = user.user_companies.first
      uc.update_attributes(:default => true)
      user.customer_id = uc.company_id
      user.save
    end
  end

  def update_es_index
    return if $redis_others.sismember("DISABLE_ES_WRITES", Account.current.id) || Account.current.features_included?(:es_v2_writes)
    AwsWrapper::SqsV2.send_message(SQS[:sqs_es_index_queue], {:op_type => "user_tickets",:user_id =>user_id, :account_id => Account.current.id}.to_json) if Account.current.esv1_enabled? && !contractor?
  end

  def contractor?
    user.contractor?
  end
end
