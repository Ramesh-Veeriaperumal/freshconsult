if Rails.env.test?
  Factory.define :forum_category  do |c|
    c.name { Faker::Lorem.words.join(' ').capitalize }
    c.description Faker::Lorem.sentence
  end


  Factory.define :forum do |f|
    f.name { Faker::Lorem.words.join(' ').capitalize }
    f.description Faker::Lorem.sentence
    f.forum_visibility  1
  end


  Factory.define :topic do |t|
    t.title { Faker::Lorem.sentence }
  end

  Factory.define :post do |p|
    p.body_html { "<p>#{Faker::Lorem.paragraph}</p>" }
  end

  Factory.define :ticket_topic do |tt|
  end

  Factory.define :monitorship, :class => Monitorship do |m|
  end

  Factory.define :vote, :class => Vote do |v|
  end

end