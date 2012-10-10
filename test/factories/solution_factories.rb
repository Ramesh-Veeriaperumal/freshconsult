Factory.define :solution_category, :class => Solution::Category do |u|
  u.account_id  1
  u.name Forgery(:lorem_ipsum).words(1)
  u.description Forgery(:lorem_ipsum).words(10)
  u.position 1
end

Factory.define :default_category, :parent => :solution_category do |u|
  u.is_default 1
end

Factory.define :folder_category, :parent => :solution_category do |u|
 u.name "Random stuff"
end



Factory.define :folder, :class => Solution::Folder do |p|
  p.name Forgery(:lorem_ipsum).words(1)
  p.description Forgery(:lorem_ipsum).words(10)
  p.association :category, :factory => :solution_category
  p.account_id 1
  p.visibility 1
end

Factory.define :default_folder, :parent => :folder do |p|
  p.name Forgery(:lorem_ipsum).words(12)
  p.association :category, :factory => :folder_category
end

Factory.define :article, :class => Solution::Article do |p|
  p.title Forgery(:lorem_ipsum).words(1)
  p.description Forgery(:lorem_ipsum).words(10)
  p.association :folder, :factory => :default_folder
  p.association :user, :factory => :poweruser
  p.account_id 1
end

Factory.define :default_article, :parent => :article do |p|
  p.title Forgery(:lorem_ipsum).words(2)
  p.association :user, :factory => :poweruser_1
  p.account_id 1
end

