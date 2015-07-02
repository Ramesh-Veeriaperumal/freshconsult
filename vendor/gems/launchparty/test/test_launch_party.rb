require 'helper'
require 'redis'
class TestLaunchParty < Minitest::Test
  
  context "LaunchParty" do
    setup do
      $red = Redis.new
      keys_to_clear = $red.keys("test_env*")
      $red.del(*keys_to_clear) unless keys_to_clear.empty?
      
      LaunchParty.configure(:redis => $red, :namespace => 'test_env')
      @lp = LaunchParty.new
      
      class Account
        attr_accessor :id
        is_a_launch_target
      end
      
      @canon = Account.new
      @canon.id = 1
      
      @nikon = Account.new
      @nikon.id = 2
      
    end

    should "instance of the right type" do
      assert_equal @lp.class.name, "LaunchParty"
    end

    should "launch feature for an account" do
      @canon.launch(:mirrorless)
      assert_equal @canon.launched?(:mirrorless), true
    end
    
    should 'return false for unlaunched feature' do
      assert_equal @canon.launched?(:medium_format), false
    end
    
    should "check if all the features are launched for an account" do
      @canon.launch(:hd_video, :fast_af)
      @canon.launch(:high_iso)
      
      added_features = [:hd_video, :fast_af, :high_iso]
      added_features.each do |f|
        assert_equal @canon.launched?(f), true
      end
      assert_equal @canon.launched?(*added_features), true
      assert_equal @canon.launched?(*(added_features | [:medium_format])), false
    end
    
    
    should "check if any of the features are launched for an account" do
      @nikon.launch(:fast_af, :high_iso)
      
      features_to_check = [:secret_feature, :fast_af, :high_iso]
      assert_equal @nikon.launched_any_of?(*features_to_check), true
      
      false_features = [:secret1, :secret2, :secret3]
      assert_equal @nikon.launched_any_of?(*false_features), false
      
    end
    
    should "return false when feature unlaunched is checked" do
      @canon.launch(:mirrorless)
      assert_equal @canon.launched?(:mirrorless), true
      
      @canon.takeback(:mirrorless)
      assert_equal @canon.launched?(:mirrorless), false
    end
    
    should "return true when feature is launched for everyone" do
      @lp.launch_for_everyone(:crop_sensor)
      assert_equal @lp.launched_for_everyone?(:crop_sensor), true
      assert_send [@lp.launched_for_everyone, :include?, :crop_sensor]
      assert_send [$red.smembers(@lp.everyone_key).map(&:to_sym), :include?,  :crop_sensor]
      
      assert_equal @canon.launched?(:crop_sensor), true
    end
    
    should "return false when feature is launched for everyone" do
      @lp.launch_for_everyone(:crop_sensor)
      assert_equal @lp.launched_for_everyone?(:crop_sensor), true
      assert_send [@lp.launched_for_everyone, :include?, :crop_sensor]
      assert_send [$red.smembers(@lp.everyone_key).map(&:to_sym), :include?,  :crop_sensor]
      
      @lp.takeback_for_everyone(:crop_sensor)
      
      assert_equal @lp.launched_for_everyone?(:crop_sensor), false
      assert_equal @lp.launched_for_everyone.include?(:crop_sensor), false
      assert_equal $red.smembers(@lp.everyone_key).map(&:to_sym).include?(:crop_sensor), false
    end
    
    should "work with direct instances" do
      @lp.launch(:magic_lantern, @canon)
      assert_equal @canon.launched?(:magic_lantern), true
      assert_equal @lp.launched?(:magic_lantern, @canon), true
      
      @lp.takeback(:magic_lantern, @canon)
      @canon.reload_features
      assert_equal @canon.launched?(:magic_lantern), false
      
      @lp.launch_for_everyone(:crop_size)
      @canon.reload_features
      @nikon.reload_features
      assert_equal @canon.launched?(:crop_size), true
      assert_equal @nikon.launched?(:crop_size), true
      
      
      @lp.takeback_for_everyone(:crop_size)
      @canon.reload_features
      @nikon.reload_features
      assert_equal @canon.launched?(:crop_size), false
      assert_equal @nikon.launched?(:crop_size), false
    end
    
    should "work directly with numbers instead of objects" do
      @lp.launch(:magic_lantern, @canon.id)
      assert_equal @canon.launched?(:magic_lantern), true
      assert_equal @lp.launched?(:magic_lantern, @canon), true
    end
    
    should "take feature back from all" do
      @canon.launch(:mirrorless)
      @nikon.launch(:mirrorless)
      sony = Account.new
      sony.id = 3
      
      assert_equal @canon.launched?(:mirrorless), true
      assert_equal @nikon.launched?(:mirrorless), true
      assert_equal sony.launched?(:mirrorless), false

      @lp.takeback_for_everyone(:mirrorless)
      
      @canon.reload_features
      @nikon.reload_features
      sony.reload_features
      
      assert_equal @canon.launched?(:mirrorless), false
      assert_equal @nikon.launched?(:mirrorless), false
      assert_equal sony.launched?(:mirrorless), false
      
      assert_equal @lp.launched_for_everyone?(:mirrorless), false
      
    end
    
    should "take all the features from an account" do
      
      added_features = [:hd_video, :fast_af, :high_iso]
      @canon.launch(*added_features)
      added_features.each do |f|
        assert_equal @canon.launched?(f), true
      end
      
      @lp.takeback_everything_for_account(@canon)
      @canon.reload_features
      added_features.each do |f|
        assert_equal @canon.launched?(f), false
      end
      
    end
    
    should "clear all the features for an object" do
      
      added_features = [:hd_video, :fast_af, :high_iso]
      @canon.launch(*added_features)
      added_features.each do |f|
        assert_equal @canon.launched?(f), true
      end
      
      @canon.clear_all_features
      added_features.each do |f|
        assert_equal @canon.launched?(f), false
      end
      
      assert_equal @lp.launched_for_account(@canon), []
    end
      
  end
end
