module Channel::V2::ApiSolutions
  class ArticleDelegator < BaseDelegator

    validate :validate_platform_params, if: -> { @platform }
    def initialize(record, params = {})
      @item = record
      @platform = params[:platform]
    end

    def validate_platform_params
      platform_mapping = @item.solution_platform_mapping
      errors[:platform] << :platform_mismatch unless platform_mapping && platform_mapping[@platform]
    end
  end
end
