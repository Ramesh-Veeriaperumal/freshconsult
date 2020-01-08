class SolutionApprovalMailer < ActionMailer::Base
  layout 'email_font'

  def notify_approval(solution_approval_mapping, to_users)
    construct_mail(solution_approval_mapping, to_users).deliver
  end

  def construct_mail(solution_approval_mapping, to_users)
    @solution_approval_mapping = solution_approval_mapping
    @to_users = to_users
    assign_common_attributes
    safe_send("construct_#{Helpdesk::ApprovalConstants::STATUS_TOKEN_BY_KEY[@solution_approval_mapping.approval_status]}_mail")
    mail_object
  end

  private

    def mail_object
      mail(@headers) do |part|
        part.text { render 'mailer/solutions/approval.text.plain.erb' }
        part.html { render 'mailer/solutions/approval.text.html.erb' }
      end
    end

    def base_headers
      {
        from: Account.current.default_friendly_email,
        to: to_addresses,
        sent_on: Time.now
      }
    end

    def to_addresses
      @to_users.map(&:email)
    end

    def assign_common_attributes
      @article_url = @solution_approval_mapping.article.agent_portal_url
      @article_title = @solution_approval_mapping.article.draft.title
      @requester_name = @solution_approval_mapping.approval.requester.name
      @approver_name = @solution_approval_mapping.approver.name
      @headers = base_headers
    end

    def construct_approved_mail
      @headers[:subject] = I18n.t('solution.notifications.article_approved_title', article_title: @article_title)
      @mail_body_html = I18n.t('solution.notifications.article_approved_body_html', article_title: @article_title, requester_name: @requester_name, approver_name: @approver_name, article_url: @article_url)
      @mail_body_txt = I18n.t('solution.notifications.article_approved_body_txt', article_title: @article_title, requester_name: @requester_name, approver_name: @approver_name, article_url: @article_url)
    end

    def construct_in_review_mail
      @headers[:subject] = I18n.t('solution.notifications.article_in_review_title', article_title: @article_title)
      @mail_body_html = I18n.t('solution.notifications.article_in_review_body_html', article_title: @article_title, requester_name: @requester_name, approver_name: @approver_name, article_url: @article_url)
      @mail_body_txt = I18n.t('solution.notifications.article_in_review_body_txt', article_title: @article_title, requester_name: @requester_name, approver_name: @approver_name, article_url: @article_url)
    end

  include MailerDeliverAlias
end
