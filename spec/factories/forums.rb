if ENV["RAILS_ENV"] == "test"
  Factory.define :forum_category  do |c|
    c.sequence(:name) { |n| "Test Category #{n}"}
    c.sequence(:description) { |n| "This is a test category #{n}."}
  end


  Factory.define :forum do |f|
    f.sequence(:name) { |n| "Test Forum #{n}"}
    f.sequence(:description) { |n| "This is a test forum #{n}."}
    f.forum_visibility  1
  end


  Factory.define :topic do |t|
    t.sequence(:title) { |n| "Test Topic #{n}"}
    t.sequence(:body_html) { |n| "<p>This is a new topic #{n}.</p>"}
  end

  Factory.define :post do |p|
    p.sequence(:body_html) { |n| "<p>This is a new post #{n}.</p>"}
  end
end