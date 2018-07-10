module TagsSandboxHelper
  MODEL_NAME = Account.reflections["tags".to_sym].klass.new.class.name
  ACTIONS = ['delete', 'update', 'create']

  def tags_data(account)
    all_tags_data = []
    ACTIONS.each do |action|
      all_tags_data << send("#{action}_tags_data", account)
    end
    all_tags_data.flatten
  end

  def create_tags_data(account)
    tags_data = []
    3.times do
      tag = account.tags.create(name: Faker::Name.name)
      tags_data << Hash[tag.attributes].merge("model"=>MODEL_NAME, "action"=>"added")
    end
    return tags_data
  end

  def update_tags_data(account)
    tag = account.tags.first
    return [] unless tag
    tag.name = 'test_update_tag_1'
    data = tag.changes.clone
    tag.save
    return Hash[data.map {|k,v| [k,v[1]]}].merge("id"=> tag.id).merge("model"=>MODEL_NAME, "action"=>"modified")
  end

  def delete_tags_data(account)
    tag = account.tags.first
    return [] unless tag
    tag.destroy
    return Hash[tag.attributes].merge("model"=>MODEL_NAME, "action"=>"deleted")
  end

end