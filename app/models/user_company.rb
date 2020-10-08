class UserCompany < ActiveRecord::Base

  self.primary_key = :id

  belongs_to_account
  belongs_to :user
  belongs_to :company

  validates_presence_of :company
  validates_uniqueness_of :company_id, :scope => [:user_id, :account_id]

  before_create :before_create_model_changes
  before_update :before_update_model_changes
  before_destroy :before_destroy_model_changes
  after_commit :associate_tickets, on: :create
  after_commit :remove_tickets_company_id, on: :destroy
  publishable on: [:create, :update, :destroy], exchange_model: :user, exchange_action: :update

  # added at last as order of central event should be primary destroy and then next primary update.
  after_commit :set_default_company, on: :destroy

  def self.has_multiple_companies?
    select(:id).group(:user_id).having("count(user_id) > 1").exists?
  end

  def override_exchange_model(_action)
    user.model_changes = @model_changes
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
    if default && user && user.user_companies.reload.present?
      uc = user.user_companies.first
      uc.update_attributes(:default => true)
      user.customer_id = uc.company_id
      user.save
    end
  end

  def contractor?
    user.contractor?
  end

  def before_create_model_changes
    @model_changes = default ? { company_id: [user.company_id, company_id] } : { other_company_ids: { added: [company_id] } }
  end

  def before_update_model_changes
    return unless default_company_changed?

    @model_changes =
      if changes['default'][1]
        { company_id: [user.company_id, company_id], other_company_ids: { removed: [company_id] } }
      else
        { company_id: [company_id, nil], other_company_ids: { added: [company_id] } }
      end
  end

  def before_destroy_model_changes
    @model_changes = default ? { company_id: [company_id, nil] } : { other_company_ids: { removed: [company_id] } }
  end

  def default_company_changed?
    changes.present? && changes.key?('default')
  end
end
