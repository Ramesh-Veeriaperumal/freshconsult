module SolutionsTemplatesTestHelper
  def disable_solutions_templates(account = Account.current)
    previous_value = account.solutions_templates_enabled?
    account.revoke_feature(:solutions_templates)
    yield
  ensure
    account.add_feature(:solutions_templates) unless previous_value
  end

  def get_sample_templates(total_cnt = 5)
    sample_templates = Account.current.solution_templates
    current_cnt = sample_templates.size
    return sample_templates if total_cnt <= current_cnt

    (total_cnt - current_cnt).times do
      sample_templates << create_sample_template
    end
    sample_templates
  end

  def create_sample_template(params = {})
    sample_template = Solution::Template.new
    sample_template.title = "Sample #{Time.now.to_i} #{Random.rand(99_999)}"
    sample_template.description = '<b> afdlsjafkj  </b>'
    sample_template.is_default = params[:is_default] if params[:is_default]
    sample_template.save
    sample_template
  end

  def create_sample_templates(template_count = 5)
    template_count.times do
      create_sample_template
    end
  end

  def destory_sample_template(template_id, account = Account.current)
    account.solution_templates.find(template_id).destroy
  end

  def template_show_pattern(template)
    template_index_element_pattern(template).merge(description: template.description)
  end

  def template_create_pattern(template)
    template_show_pattern(template)
  end

  def template_index_element_pattern(template)
    {
      id: template.id,
      title: template.title,
      agent_id: template.user_id,
      modified_by: template.modified_by,
      modified_at: template.modified_at.try(:utc).try(:iso8601),
      is_active: template.is_active,
      is_default: template.is_default,
      created_at: template.created_at.try(:utc).try(:iso8601),
      usage: 0
    }
  end

  def template_index_pattern(templates)
    templates.map { |template| template_index_element_pattern(template) }
  end
end
