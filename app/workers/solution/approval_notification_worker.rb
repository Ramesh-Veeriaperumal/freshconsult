class Solution::ApprovalNotificationWorker < BaseWorker
  sidekiq_options queue: :kbase_approval_notification_worker, retry: 4, failures: :exhausted

  include Helpdesk::IrisNotifications

  def perform(args)
    args.symbolize_keys!
    @solution_approval_mapping = Solution::ApproverMapping.new(Account.current.helpdesk_approver_mappings.where(id: args[:id]).first)
    Rails.logger.info "AA::Approval sending notification:: [#{Account.current.id}, #{@solution_approval_mapping.article.id}, #{@solution_approval_mapping.approval_status}] #{@solution_approval_mapping.article.title}"
    @to_users = to_users
    return if @to_users.empty?
    push_data_to_service(IrisNotificationsConfig['api']['collector_path'], iris_payload)
    SolutionApprovalMailer.notify_approval(@solution_approval_mapping, @to_users)
  rescue => e # rubocop:disable RescueStandardError
    Rails.logger.info "AA::Exception while sending approval notification [#{Account.current.id}] #{e.message} - #{e.backtrace}"
    NewRelic::Agent.notice_error(e, account: Account.current.id, description: "AA::Exception while sending approval notification [#{Account.current.id}] #{e.message} - #{e.backtrace}")
  end

  private

    def approval_notification_type
      Helpdesk::ApprovalConstants::IRIS_NOTIFICATION_TYPE[@solution_approval_mapping.approval_status]
    end

    def iris_payload
      article = @solution_approval_mapping.article
      {
        payload: {
          title: article.draft.title,
          actor: User.current.name,
          user_ids: @to_users.map(&:id),
          article_url: article.agent_portal_url(true)
        },
        payload_type: approval_notification_type,
        account_id: Account.current.id.to_s
      }
    end

    def to_users
      user_ids = []
      user_ids << @solution_approval_mapping.notify_to if User.current.id != @solution_approval_mapping.notify_to
      draft_author_id = @solution_approval_mapping.article.draft.user_id
      # if the requester is different from draft author we need to send notification for both the users on approval
      if @solution_approval_mapping.approved? && User.current.id != draft_author_id && draft_author_id != @solution_approval_mapping.approval.user_id
        user_ids << draft_author_id
      end
      Account.current.users.where(id: user_ids, helpdesk_agent: true).to_a
    end
end
