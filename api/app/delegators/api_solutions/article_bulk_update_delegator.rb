module ApiSolutions
  class ArticleBulkUpdateDelegator < BaseDelegator
    include SolutionApprovalConcern

    attr_accessor :agent_id, :tags, :portal_id, :folder_id, :approval_status, :approver_id, :status

    validate :agent_exists?, if: -> { @agent_id }
    validate :create_tag_permission, if: -> { @tags }
    validate :folder_exists?, if: -> { @folder_id }
    validate :validate_publish_permission, if: -> { @status }
    validate :validate_approval_permission, if: -> { @approval_status && article_approval_workflow_enabled? }
    validate :validate_create_and_edit_permission, if: -> { @approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review] && article_approval_workflow_enabled? }

    def initialize(options)
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      super(options)
    end

    def agent_exists?
      unless User.current.privilege?(:admin_tasks)
        (error_options[:properties] ||= {}).merge!(nested_field: :agent_id, code: :cannot_change_author_id)
        errors[:properties] = :cannot_change_author_id
        return false
      end

      unless Account.current.agents_details_from_cache.detect { |x| x.id == @agent_id && x.privilege?(:publish_solution) }
        (error_options[:properties] ||= {}).merge!(nested_field: :agent_id, code: :invalid_agent_id)
        errors[:properties] = :invalid_agent_id
        return false
      end
    end

    def folder_exists?
      if Account.current.solution_folder_meta.where('id' => @folder_id).empty?
        (error_options[:properties] ||= {}).merge!(nested_field: :folder_id, code: :invalid_folder_id)
        errors[:properties] = :invalid_folder_id
      end
    end

    def validate_approval_permission
      if @approver_id
        unless approve_permission?(@approver_id)
          (error_options[:properties] ||= {}).merge!(nested_field: :approve_privilege, code: :no_approve_article_privilege)
          errors[:properties] = :no_approve_article_privilege
        end
      else
        unless approve_permission?(User.current)
          (error_options[:properties] ||= {}).merge!(nested_field: :approve_privilege, code: :no_approve_article_privilege)
          errors[:properties] = :no_approve_article_privilege
        end
      end
    end

    def validate_create_and_edit_permission
      unless User.current.privilege?(:create_and_edit_article)
        (error_options[:properties] ||= {}).merge!(nested_field: :create_and_edit_article, code: :no_create_and_edit_article_privilege)
        errors[:properties] = :no_create_and_edit_article_privilege
      end
    end

    def validate_publish_permission
      unless User.current.privilege?(:publish_solution) || (article_approval_workflow_enabled? && User.current.privilege?(:publish_approved_solution))
        (error_options[:properties] ||= {}).merge!(nested_field: :publish_solution, code: :no_publish_article_privilege)
        errors[:properties] = :no_publish_article_privilege
      end
    end

    def create_tag_permission
      unless User.current.privilege?(:create_tags)
        new_tags = @tags - Account.current.tags.where(name: @tags).map(&:name)
        if new_tags.present?
          errors[:tags] << 'cannot_create_new_tag'
          @error_options[:tags] = { tags: new_tags }
        end
      end
    end

    private

      def article_approval_workflow_enabled?
        Account.current.article_approval_workflow_enabled?
      end
  end
end
