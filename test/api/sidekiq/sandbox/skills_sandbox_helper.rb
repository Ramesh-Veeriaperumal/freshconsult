module SkillsSandboxHelper


  ACTIONS = ['delete', 'update', 'create']

  def skills_data(account)
    all_skills_data = []
    ACTIONS.each do |action|
      all_skills_data << send("#{action}_skills_data", account)
    end
    all_skills_data.flatten
  end


  def create_skills_data(account)
    skills_data = []
    3.times do
      skill = account.skills.build({name: Faker::Name.name, description: Faker::Lorem.sentence(2),match_type: "all", filter_data:  [{"evaluate_on"=>"ticket", "name"=>"priority", "operator"=>"in", "value"=>"1"}]})
      skill.save
      skills_data << [skill.attributes.merge({"action" => 'added', "model" => skill.class.name})]
    end
    skills_data.flatten
  end

  def delete_skills_data(account)
    skill = account.skills.last
    return [] unless skill
    data = skill.attributes.clone
    skill.destroy
    [data.merge({"action" => 'deleted', "model" => skill.class.name})]
  end

  def update_skills_data(account)
    skill = account.skills.last
    return [] unless skill
    skill.name = Faker::Name.name
    skill.description = Faker::Lorem.sentence(2)
    data = skill.changes.clone
    skill.save
    [Hash[data.map { |k, v| [k, v[1]] }].merge({"id" =>skill.id, "action" => 'modified', "model" => skill.class.name })]
  end
end