module SolutionApprovalConcern
  extend ActiveSupport::Concern

  def approve_permission?(user)
    user = get_user_record(user)
    user && user.privilege?(:approve_article)
  end

  def get_or_build_approval_record(article)
    article.helpdesk_approval || construct_approval_record(article)
  end

  def get_or_build_approver_mapping(helpdesk_approval, approver_id)
    # TODO : for multplie aprovers, need to think of an efficient way other than :sample. :autosave won't work if we use :where of :first condition
    helpdesk_approver = helpdesk_approval.approver_mappings.sample || construct_approver_mapping(helpdesk_approval, approver_id)
    helpdesk_approver.approver_id = approver_id
    helpdesk_approver
  end

  def get_user_record(user)
    return user if user.instance_of? User
    Account.current.technicians.where(id: user).first
  end

  private

    def construct_approval_record(article)
      review_params = {}
      review_params[:approval_status] = Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
      review_params[:user_id] = User.current.id
      article.build_helpdesk_approval(review_params)
    end

    def construct_approver_mapping(helpdesk_approval, approver_id)
      review_params = {}
      review_params[:approval_status] = Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
      review_params[:approver_id] = approver_id
      helpdesk_approval.approver_mappings.build(review_params)
    end
end
