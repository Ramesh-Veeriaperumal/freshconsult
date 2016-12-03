module FdSpamDetectionService
  class Result

    def initialize(hash)
      @data = hash
    end

    def spam?
      @data['is_spam'].to_s.to_bool
    end

    def score
      @data['score'].to_f
    end

    def rules
      @data['rules']
    end

    def threshold
      @data['required_score'].to_f
    end

    def to_param
      JSON.parse(@data.body) if @data.present?
    end

  end
end