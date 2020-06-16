class Helpdesk::Approval < ActiveRecord::Base
  self.table_name =  'helpdesk_approvals'
  self.primary_key = :id

  belongs_to_account

  belongs_to :approvable, polymorphic: true
  belongs_to :requester, class_name: 'User', foreign_key: 'user_id'

  # before_destroy callbacks should be placed before dependent: :destroy
  before_destroy :approval_changes_on_destroy
  has_many :approver_mappings, class_name: 'Helpdesk::ApproverMapping', inverse_of: :approval, dependent: :destroy, autosave: true

  validates :account_id, presence: true
  validates :user_id, presence: true
  validates :approvable_type, presence: true
  validates :approvable_id, presence: true
  validates :approval_status, inclusion: {
    in: [Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected]]
  }, presence: true

  scope :solution_approvals, -> { where(approvable_type: 'Solution::Article') }

  after_commit :approval_changes_on_create, on: :create
  after_commit :approval_changes_on_update, on: :update
  after_commit :publish_article_approver_changes

  after_commit :trigger_callback

  def in_review?
    approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
  end

  def approved?
    approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
  end

  def rejected?
    approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:rejected]
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

  def model_changes
    @model_changes ||= {}
  end

  def approval_changes_on_create
    # If the status is not in-review when 'Create', it is required to handle those cases
    model_changes[:approval_status] = [nil, approval_status]

    # When approved article is edited and then cancel is clicked, approval values need to be retained
    if approved?
      model_changes[:approved_at] = [nil, approved_at]
      model_changes[:approved_by] = [nil, approved_by]
    end
  end

  def approval_changes_on_update
    # Handle updates only when not in IN-Review status
    return unless approval_status != Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]

    model_changes[:approval_status] = [Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review], approval_status]
    if approved?
      model_changes[:approved_at] = [nil, approved_at]
      model_changes[:approved_by] = [nil, approved_by]
    end
  end

  def approval_changes_on_destroy
    model_changes[:approval_status] = [approval_status, nil]
    if approved?
      model_changes[:approved_at] = [approved_at, nil]
      model_changes[:approved_by] = [approved_by, nil]
    end
  end

  # Publish approver changes to central as a part of Article payload
  # A new column - approved_at can be added in approver_mapping table later, instead using updated_at for now.
  # Need to handle multi-approver case when it comes.
  def publish_article_approver_changes
    approvable.publish_approver_changes_to_central(model_changes) if approvable_type == 'Solution::Article' && !model_changes.empty?
  end

  # returns the first approver if approved
  def approved_by
    approver_mappings.first.approver_id if approved?
  end

  # returns the first approved time
  def approved_at
    updated_at if approved?
  end
end
