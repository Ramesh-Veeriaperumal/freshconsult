module Admin
  class ShiftValidation < ApiValidation
    include Admin::ShiftConstants
    attr_accessor(*REQUEST_PERMITTED_PARAMS)

    validates :name, presence: true, on: :create
    validates :time_zone, presence: true, on: :create
    validates :name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, if: -> { name.present? }
    validates :time_zone, data_type: { rules: String }, if: -> { time_zone.present? }
    validates :work_days, data_type: { rules: Array }, array: { data_type: { rules: Hash, required: true },
                                                                hash: { day: { data_type: { rules: String, required: true } },
                                                                        start_time: { data_type: { rules: String, required: true } },
                                                                        end_time: { data_type: { rules: String, required: true } } } }, if: -> { work_days.present? }
    validates :agents, data_type: { rules: Array }, array: { data_type: { rules: Hash, required: true },
                                                             hash: { id: { data_type: { rules: Integer, required: true } } } }, if: -> { agents.present? }

    validate :validate_agents, if: -> { agents.present? }

    def initialize(request_params, agent_ids)
      REQUEST_PERMITTED_PARAMS.each { |param| safe_send("#{param}=", request_params[param]) }
      @agent_ids = agent_ids
      super(request_params)
    end

    private

      def validate_agents
        actual = agents.map { |agent| agent[:id] }
        if actual.uniq.count != actual.count
          errors[:agents] << :duplicate_agent_present
        elsif actual & @agent_ids != actual
          errors[:agents] << :invalid_list
          (error_options[:agents] ||= {}).merge!(list: (actual - @agent_ids).join(', '))
        end
      end
  end
end
