class SolutionApprovalMailer < ActionMailer::Base
  layout 'email_font'

  def notify_approval(solution_approval_mapping, to_users)
    self.class.send_email_to_group(:construct_mail_and_send, to_users.map(&:email), solution_approval_mapping, to_users)
  end

  # if you use this method directly, user locale won't be handled. use :notify_approval method instead
  def construct_mail_and_send(emails, solution_approval_mapping, to_users)
    @solution_approval_mapping = solution_approval_mapping
    @to_emails = emails[:group]
    @other_emails = emails[:other]
    @email_vs_name = {}
    to_users.each do |user|
      @email_vs_name[user.email] = user.name
    end
    assign_common_attributes
    Rails.logger.info "AA::Approval sending mail:: [#{@to_emails}, #{@article_title}]"
    @to_emails.each do |email|
      @to_email = email
      @user_name = @email_vs_name[email]
      safe_send("construct_#{Helpdesk::ApprovalConstants::STATUS_TOKEN_BY_KEY[@solution_approval_mapping.approval_status]}_mail")
      mail_object.deliver
    end
  end

  private

    def mail_object
      mail(headers) do |part|
        part.text { render 'mailer/solutions/approval.text.plain.erb' }
        part.html { render 'mailer/solutions/approval.text.html.erb' }
      end
    end

    def headers
      {
        from: Account.current.default_friendly_email,
        to: @to_email,
        sent_on: Time.now,
        subject: @subject
      }
    end

    def assign_common_attributes
      @article_url = @solution_approval_mapping.article.agent_portal_url
      @article_title = @solution_approval_mapping.article.draft.title
      @requester_name = @solution_approval_mapping.approval.requester.name
      @approver_name = @solution_approval_mapping.approver.name
    end

    def construct_approved_mail
      @subject = I18n.t('mailer_notifier.solutions_approval.article_approved_title', article_title: @article_title)
      @mail_body_html = I18n.t('mailer_notifier.solutions_approval.article_approved_body_html', article_title: @article_title, user_name: @user_name, approver_name: @approver_name, article_url: @article_url).html_safe # rubocop:disable Rails/OutputSafety
      @mail_body_txt = I18n.t('mailer_notifier.solutions_approval.article_approved_body_txt', article_title: @article_title, user_name: @user_name, approver_name: @approver_name, article_url: @article_url)
    end

    def construct_in_review_mail
      @subject = I18n.t('mailer_notifier.solutions_approval.article_in_review_title', article_title: @article_title)
      @mail_body_html = I18n.t('mailer_notifier.solutions_approval.article_in_review_body_html', article_title: @article_title, requester_name: @requester_name, approver_name: @approver_name, article_url: @article_url).html_safe # rubocop:disable Rails/OutputSafety
      @mail_body_txt = I18n.t('mailer_notifier.solutions_approval.article_in_review_body_txt', article_title: @article_title, requester_name: @requester_name, approver_name: @approver_name, article_url: @article_url)
    end

  include MailerDeliverAlias
end
