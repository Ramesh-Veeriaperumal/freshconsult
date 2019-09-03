module BccConcern
  extend ActiveSupport::Concern

  def build_bcc_params(bcc_emails)
    sanitized_emails = bcc_emails.select do |email|
      email.strip!
      email.downcase!
      email.present?
    end
    sanitized_emails.uniq.join(',')
  end
end
