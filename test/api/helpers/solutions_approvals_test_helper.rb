module SolutionsApprovalsTestHelper
  include SolutionsArticlesTestHelper

  def approver_record(article)
    @approver_record = approval_record(article).try(:approver_mappings).try(:first)
  end

  def approval_record(article)
    @approval_record = article.helpdesk_approval
  end

  def assert_no_approval(article)
    article.reload
    assert article.helpdesk_approval.nil?
  end

  def assert_in_review(article)
    article.reload
    assert article.helpdesk_approval.approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
  end

  def assert_approved(article)
    article.reload
    assert article.helpdesk_approval.approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
  end

  def get_in_review_article(language = Account.current.language_object, user = User.current, approver = User.current)
    article = get_article_with_draft(language)
    if article.helpdesk_approval
      article.helpdesk_approval.destroy
      article.reload
    end
    approval = construct_approval_record(article, user)
    construct_approver_mapping(approval, approver)
    approval.save
    article.reload
  end

  def get_approved_article(language = Account.current.language_object, user = User.current, approver = User.current)
    article = get_article_with_draft(language)
    if article.helpdesk_approval
      article.helpdesk_approval.destroy
      article.reload
    end
    approval = construct_approval_record(article, user)
    approval.approval_status = Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
    approval_mapping = construct_approver_mapping(approval, approver)
    approval_mapping.approval_status = Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
    approval.save
    article.reload
  end


  def construct_approval_record(article, user)
    review_params = {}
    review_params[:approval_status] = Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
    review_params[:user_id] = user.id
    article.build_helpdesk_approval(review_params)
  end

  def construct_approver_mapping(helpdesk_approval, approver)
    review_params = {}
    review_params[:approval_status] = Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
    review_params[:approver_id] = approver.id
    helpdesk_approval.approver_mappings.build(review_params)
  end
end