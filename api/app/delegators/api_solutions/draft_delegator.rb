module ApiSolutions
  class DraftDelegator < BaseDelegator
    include SolutionConcern
    include SolutionApprovalConcern

    validate :validate_portal_id, if: -> { @portal_id }
    validate :validate_author, on: :update
    validate :validate_approval_data, on: :update

    def initialize(record, options = {})
      @item = record
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(record, options)
    end

    def validate_author
      author = get_user_record(@user_id)
      errors[:user_id] << :invalid_draft_author unless author && author.privilege?(:create_and_edit_article)
    end

    def validate_approval_data
      if @approval_data.present?
        unless approve_permission?(@approval_data[:approver_id])
          (error_options[:approval_data] ||= {}).merge!(nested_field: :approver_id, code: :invalid_approver_id)
          errors[:approval_data] = :invalid_approver_id
        end
        user = get_user_record(@approval_data[:user_id])
        unless user
          (error_options[:approval_data] ||= {}).merge!(nested_field: :user_id, code: :invalid_user_id)
          errors[:approval_data] = :invalid_user_id
        end
      end
    end
  end
end
