module ApiSolutions
  class ArticleBulkUpdateDelegator < BaseDelegator
    attr_accessor :agent_id, :tags, :portal_id, :folder_id

    validate :agent_exists?, if: -> { @agent_id }
    validate :create_tag_permission, if: -> { @tags }
    validate :folder_exists?, if: -> { @folder_id }

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

    def create_tag_permission
      new_tags = @tags - Account.current.tags.where(name: @tags).map(&:name)
      if new_tags && !User.current.privilege?(:create_tags)
        errors[:tags] << 'cannot_create_new_tag'
        @error_options[:tags] = { tags: new_tags }
      end
    end
  end
end