# How to Use

Configure LaunchParty in an initializer
```ruby
LaunchParty.configure({
    :redis => Redis.new,
    :namespace => 'nexgen_features'
})
```

Add the `is_a_launch_target` method to your ActiveRecord model or any class.
```ruby
class Account
  attr_accessor :id
  is_a_launch_target
end
```

```ruby

a = Account.new
a.id = 1
a.launch(:some_feature)
a.launched?(:some_feature) #=> true
a.launch(:another)
a.launched?(:another) #=> true
a.takeback(:another)
a.launched?(:another) #=> Now false

l = LaunchParty.new
l.launch_for_everyone(:global_stuff)

b = Account.new
b.id = 2
b.launched?(:some_feature) #=> false
b.launch(:some_feature)
b.launched?(:some_feature) #=> true

b.launched?(:global_stuff) #=> true
```