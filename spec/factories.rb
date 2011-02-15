# By using the symbol ':forum_category', we get Factory Girl to simulate the ForumCategory model.
Factory.define :forum_category do |forum_category|
  forum_category.name            "Freshdesk"
  forum_category.description     "Freshdesk Description"
  forum_category.account_id      1
end

Factory.define :user do |user|
  user.name            "Freshdesk"
  user.email     "freshdesk@freshdesk.com"
end

Factory.define :forum do |forum|
  forum.name "Freshdesk Forum"
  forum.association :forum_category
end

Factory.define :topic do |topic|
  topic.title "Freshdesk Topic"
  topic.user_id 1
  topic.association :forum
end

