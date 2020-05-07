module Ember::Solutions
  class TemplateDelegator < BaseDelegator
    validate :uniq_title, if: -> { !@title.empty? }
    validate :templates_max_count

    def initialize(record, params = {})
      @item = record
      @title = params[:title]
      super(params)
    end

    def uniq_title
      duplicate_template = Account.current.solution_templates.where(title: @title).first
      errors[:title] << :duplicate_title unless duplicate_template.nil? || duplicate_template.id == @item.id
    end

    def templates_max_count
      errors[:templates_count] << :reached_max_count unless Account.current.solution_templates.size <= Ember::Solutions::TemplateConstants::MAX_TEMPLATES_COUNT
    end
  end
end
