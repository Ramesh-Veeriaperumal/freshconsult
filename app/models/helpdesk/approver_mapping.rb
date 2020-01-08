class Helpdesk::ApproverMapping < ActiveRecord::Base

  self.table_name =  'helpdesk_approver_mappings'
  self.primary_key = :id

  belongs_to_account

  belongs_to :approval, class_name: 'Helpdesk::Approval', inverse_of: :approver_mappings
  belongs_to :approver, class_name: 'User', foreign_key: 'approver_id'

  validates :account_id, presence: true
  validates :approver_id, presence: true

  validates :approval_status, inclusion: {
    in: [Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected]]
  }, presence: true

  after_save :send_approval_notification, if: -> { approval.approvable_type == 'Solution::Article' && changes.key?(:approval_status) }

  def approve!
    self.approval_status = Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
    save
    approval.update_approval_status!
  end

  def in_review?
    approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
  end

  def approved?
    approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
  end

  private

    def send_approval_notification
      ::Solution::ApprovalNotificationWorker.perform_async(id: id)
    end
end
