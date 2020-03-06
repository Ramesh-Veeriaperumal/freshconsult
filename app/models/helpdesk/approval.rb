class Helpdesk::Approval < ActiveRecord::Base
  self.table_name =  'helpdesk_approvals'
  self.primary_key = :id

  belongs_to_account

  belongs_to :approvable, polymorphic: true
  belongs_to :requester, class_name: 'User', foreign_key: 'user_id'

  has_many :approver_mappings, class_name: 'Helpdesk::ApproverMapping', inverse_of: :approval, dependent: :destroy, autosave: true

  validates :account_id, presence: true
  validates :user_id, presence: true
  validates :approvable_type, presence: true
  validates :approvable_id, presence: true
  validates :approval_status, inclusion: {
    in: [Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected]]
  }, presence: true


  after_commit :trigger_callback

  scope :solution_approvals, conditions: { approvable_type: 'Solution::Article' }

  def in_review?
    approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
  end

  def approved?
    approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
  end

  def update_approval_status!
    approver_statuses = approver_mappings.pluck_all(:approval_status)
    # If anyone rejected, then it is rejected. For, other cases we need to handle w.r.t approval type. For now it requires everyone approval.
    self.approval_status = if approver_statuses.any? { |status| status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected] }
                             Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected]
                           elsif approver_statuses.any? { |status| status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review] }
                             Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
                           else
                             Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
                           end
    save
  end

  def approver?(user_id)
    approver_mappings.where(approver_id: user_id).present?
  end

  def trigger_callback
    action = transaction_include_action?(:create) ? 'create' : transaction_include_action?(:destroy) ? 'destroy' : 'update'
    begin
      model_class = self.approvable_type.constantize
      record = model_class.where(account_id: Account.current.id, id: self.approvable_id).first
      if record
        record.safe_send('approval_callback', action, self) if model_class.method_defined?('approval_callback')
      end
    rescue StandardError => e
      Rails.logger.error "Error while triggering callback  #{action} on #{model_class} #{e}"
    end
  end
end
