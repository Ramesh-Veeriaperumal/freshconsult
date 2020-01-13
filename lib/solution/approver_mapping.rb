class Solution::ApproverMapping < SimpleDelegator
  # this class expects helpdesk_approver_mapping as a constructor params.
  # As helpdesk_approver_mapping is polymorphic, all solution related logic related to approvals lies here.

  def article
    @article ||= Account.current.solution_articles.find(approval.approvable_id)
  end

  def article_meta
    @article_meta ||= article.article_meta
  end

  def notify_to
    if approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
      approver_id
    elsif approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
      approval.user_id
    end
  end
end
