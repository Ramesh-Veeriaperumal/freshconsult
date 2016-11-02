class ContactMergeDelegator < BaseDelegator
  attr_accessor :target_users

  validate :validate_target_ids, if: -> { @target_ids.present? }
  validate :check_limits, if: -> { @target_ids && errors[:target_ids].blank? }

  def initialize(record, options = {})
    super(record)
    @target_ids = options[:target_ids]
    fetch_target_users(options[:scoper]) if @target_ids
  end

  def validate_target_ids
    invalid_ids = @target_ids - @target_users.map(&:id)
    if invalid_ids.any?
      errors[:target_ids] << :invalid_list
      error_options.merge!(target_ids: { list: invalid_ids.join(', ') })
    end
  end

  def check_limits
    ContactConstants::MERGE_VALIDATIONS.each do |att|
      if exceeded_user_attribute(att[0], att[1])
        errors[att[0].to_sym] << :contact_merge_validation
        error_options.merge!(att[0].to_sym => { max_value: att[1], field: att[2] })
      end
    end
  end

  private

    def fetch_target_users(scoper)
      @target_users = scoper.without(self).where(id: @target_ids)
    end

    def exceeded_user_attribute(att, max)
      [send(att), @target_users.map { |x| x.send(att) }].flatten.compact.reject(&:empty?).uniq.length > max
    end
end
