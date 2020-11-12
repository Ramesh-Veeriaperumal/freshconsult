class Redaction
  attr_accessor :data, :configs, :settings, :options

  def initialize(data: nil, configs: nil, settings: nil)
    self.data = Array.wrap(data)
    self.configs = configs
    self.settings = settings
    initialize_options
  end

  def initialize_options
    self.options = configs.keys.each_with_object({}) do |key, options|
      options[key] = "Redaction::Constants::#{key.upcase}_DEFAULT_OPTIONS".constantize.dup
      options[key].merge!(settings.try(:[], key).to_h)
    end
  end

  def redact!
    data.each do |input_data|
      next if input_data.blank?

      configs.each_pair do |key, value|
        safe_send("redact_#{key}!", input_data, options[key]) if value
      end
    end
    data
  rescue StandardError => e
    Rails.logger.error("Error in Redaction :: #{e.message}")
    NewRelic::Agent.notice_error(e)
  end

  def redact_credit_card_number!(redaction_input, options)
    time_taken = Benchmark.realtime { CreditCardSanitizer.new(options).sanitize!(redaction_input) }
    Rails.logger.info "Time taken for Credit card number redaction - #{time_taken}"
  end
end
