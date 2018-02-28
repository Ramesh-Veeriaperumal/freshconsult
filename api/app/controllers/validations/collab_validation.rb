class CollabValidation < ApiValidation
  attr_accessor :body, :m_ts, :m_type, :metadata, :mid, :token, :top_members, :only
  validates :body, :m_ts, :m_type, :metadata, :token, :top_members, data_type: { rules: String, allow_blank: false }
  validates :body, :metadata, :token, data_type: { required: true, rules: String }
  validate :json_format, if: -> { errors[:content].blank? }

  def json_format
    errors[:metadata] << 'It should be in valid json format.' unless is_json?(metadata)
  end

  private

    def is_json?(data)
      !!JSON.parse(data)
    rescue
      false
    end
end
