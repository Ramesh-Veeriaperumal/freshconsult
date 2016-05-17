module Helpdesk::Permission
  module Util

    include ParserUtil

    def valid_permissible_user?(email, account = Account.current)
      return true unless account.restricted_helpdesk?

      valid_emails = fetch_valid_emails(email)
      return false if valid_emails.length == 0

      user_email = valid_emails[0]
      domain     = parse_email_with_domain(user_email)[:domain]
      valid_contact?(account, user_email) || valid_domain?(account, domain)
    end

    def valid_permissible_domain?(email, account = Account.current)
      return true unless account.restricted_helpdesk?

      valid_emails = fetch_valid_emails(email)
      return false if valid_emails.length == 0

      domain = parse_email_with_domain(valid_emails[0])[:domain]
      valid_domain?(account, domain)
    end

    private

    def valid_contact? account, email
      account.user_emails.user_for_email(email, account).present?
    end

    def valid_domain? account, domain
      company_domain?(account, domain) || white_listed_domain?(account, domain)
    end

    def company_domain? account, domain
      account.company_domains.exists?(:domain => domain)
    end

    def account_company_domains account, domains
      account.company_domains.where(:domain => domains).pluck(:domain)
    end

    def account_helpdesk_permissible_domains account, domains
      account.helpdesk_permissible_domains.where(:domain => domains).pluck(:domain)
    end

    def white_listed_domain? account, domain
      account.helpdesk_permissible_domains_from_cache.map(&:domain).include?(domain)
    end

    def valid_emails(account, emails)
      return {valid_emails: emails, dropped_emails: ""} unless account.restricted_helpdesk?
      emails = fetch_valid_emails(emails)
      emails = emails.map { |email| parse_email_text(email)[:email] } if emails.count > 0
      initial_valid_emails = emails

      contact_emails  = account.user_emails.existing_emails_for_emails(emails, account)
      emails          = emails - contact_emails
      emails_hash     = emails.map{|x| parse_email_with_domain(x)}

      email_domains = emails_hash.map{|x| x[:domain]}

      valid_domains     = (account_company_domains(account, email_domains) + account_helpdesk_permissible_domains(account, email_domains)).uniq.to_a
      valid_emails_hash = emails_hash.select{|email_hash| valid_domains.include?(email_hash[:domain])}
      domain_emails     = valid_emails_hash.map{|x| x[:email]}

      final_valid_emails = (contact_emails + domain_emails).uniq.to_a

      dropped_emails = (initial_valid_emails - final_valid_emails).uniq.join(",")

      final_valid_emails = final_valid_emails.join(",")
      return {valid_emails: final_valid_emails, dropped_emails: dropped_emails}
    end

    # def valid_emails(account, emails)
    #   if account.restricted_helpdesk?
    #     valid_emails = []
    #     dropped_emails = []
    #     emails = fetch_valid_emails(emails).map { |email| parse_email_text(email)[:email] }
    #     emails.each do |email|
    #       if valid_permissible_user? email
    #         valid_emails << email
    #       else
    #         dropped_emails << email
    #       end
    #     end
    #     {valid_emails: valid_emails.uniq.join(","), dropped_emails: dropped_emails.uniq.join(",")}
    #   else
    #     {valid_emails: emails, dropped_emails: ""}
    #   end
    # end
    
  end
end