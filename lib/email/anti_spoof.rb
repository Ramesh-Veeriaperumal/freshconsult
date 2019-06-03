module Email::AntiSpoof
  DKIM_PASS_STATUSES = %w[DKIM_VALID DKIM_VALID_AU DKIM_VERIFIED].freeze
  DKIM_FAIL_STATUSES = %w[DKIM_ADSP_NXDOMAIN DKIM_ADSP_DISCARD DKIM_ADSP_ALL
                          DKIM_ADSP_CUSTOM_LOW DKIM_ADSP_CUSTOM_MED DKIM_ADSP_CUSTOM_HIGH
                          DKIM_POLICY_SIGNSOME DKIM_POLICY_SIGNALL DKIM_INVALID].freeze
  DKIM = 'DKIM'.freeze
  SPF = 'SPF'.freeze

  SPF_PASS_STATUSES = %w[SPF_PASS SPF_HELO_PASS].freeze
  SPF_FAIL_STATUSES = %w[SPF_NEUTRAL SPF_FAIL SPF_SOFTFAIL SPF_HELO_NEUTRAL
                         SPF_HELO_FAIL SPF_HELO_SOFTFAIL].freeze

  def generate_spoof_data_hash(spam_info)
    return generate_spoof_hash if spam_info.nil? || spam_info['rules'].nil?

    dkim_status = verify_trusted_source(spam_info['rules'], DKIM)
    spf_status = verify_trusted_source(spam_info['rules'], SPF)
    generate_spoof_hash(dkim_status, spf_status)
  end

  def verify_trusted_source(rules, type)
    email_statuses = fetch_incoming_email_statuses(rules, type)
    compute_email_trust_status(email_statuses, type) if email_statuses.present?
  end

  def fetch_incoming_email_statuses(rules, type)
    rules.select { |rule| rule.start_with?(type) }
  end

  def compute_email_trust_status(statuses, type)
    if type == DKIM
      check_dkim_status(statuses)
    else
      check_spf_status(statuses)
    end
  end

  def check_dkim_status(statuses)
    statuses.any? { |status| DKIM_PASS_STATUSES.include?(status) } &&
      statuses.none? { |status| DKIM_FAIL_STATUSES.include?(status) }
  end

  def check_spf_status(statuses)
    statuses.any? { |status| SPF_PASS_STATUSES.include?(status) } &&
      statuses.none? { |status| SPF_FAIL_STATUSES.include?(status) }
  end

  def generate_spoof_hash(dkim_status = nil, spf_status = nil)
    { email_spoof_data: { DKIM: dkim_status, SPF: spf_status } }
  end
end
