class Helpdesk::Approval < ActiveRecord::Base
  self.table_name =  'helpdesk_approvals'
  self.primary_key = :id

  belongs_to_account

  belongs_to :approvable, polymorphic: true

  has_many :approver_mappings, class_name: 'Helpdesk::ApproverMapping', inverse_of: :approval, dependent: :destroy, autosave: true

  validates :account_id, presence: true
  validates :user_id, presence: true
  validates :approvable_type, presence: true
  validates :approvable_id, presence: true

  validates :approval_status, inclusion: {
    in: [Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected]]
  }, presence: true
end
