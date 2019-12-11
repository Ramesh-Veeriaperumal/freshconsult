class Helpdesk::ApproverMapping < ActiveRecord::Base
  self.table_name =  'helpdesk_approver_mappings'
  self.primary_key = :id

  belongs_to_account

  belongs_to :approval, class_name: 'Helpdesk::Approval', inverse_of: :approver_mappings

  validates :account_id, presence: true
  validates :approver_id, presence: true

  validates :approval_status, inclusion: {
    in: [Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected]]
  }, presence: true
end
