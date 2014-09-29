Factory.define :customer do |p|
  p.account_id 1
  p.name  Forgery(:lorem_ipsum).words(1)
end

Factory.define :article_customer, :class => Company do |p|
  p.account_id 1
  p.name  Forgery(:lorem_ipsum).words(2)
end

Factory.define :article_customer_1, :class => Company do |p|
  p.account_id 1
  p.name  Forgery(:lorem_ipsum).words(2)
end