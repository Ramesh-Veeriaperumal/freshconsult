Factory.define :customer do |p|
  p.account_id 1
  p.name  Forgery(:lorem_ipsum).words(1)
end

Factory.define :article_customer, :class => Customer do |p|
  p.account_id 1
  p.name  Forgery(:lorem_ipsum).words(2)
end

Factory.define :article_customer_1, :class => Customer do |p|
  p.account_id 1
  p.name  Forgery(:lorem_ipsum).words(2)
end