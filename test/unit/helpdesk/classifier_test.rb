require 'test_helper'

class Helpdesk::ClassifierTest < ActiveSupport::TestCase
  should_validate_presence_of :name, :categories
  should_validate_uniqueness_of :name
  should_ensure_length_in_range :name, (1..120) 
  should_ensure_length_in_range :categories, (1..120) 
  should_have_instance_methods :brain, :train, :untrain, :category?

  context "A new classifier" do
    setup { @classifier = Helpdesk::Classifier.new }

    should "create new bayesian classifier if data is nil" do
      @classifier.expects(:data).returns(nil)
      @classifier.expects(:categories).returns('one two')
      Marshal.expects(:load).never
      Classifier::Bayes.expects(:new).with('one', 'two').returns(:the_brain)
      assert_equal :the_brain, @classifier.brain
    end

    should "load bayesian classifier from data if data is nonempty" do
      @classifier.expects(:data).times(2).returns(:some_data)
      @classifier.expects(:categories).never
      Classifier::Bayes.expects(:new).never
      Marshal.expects(:load).with(:some_data).returns(:the_brain_on_ice)
      assert_equal :the_brain_on_ice, @classifier.brain
    end


    context "A mock brain" do
      setup do
        @brain = mock 
        @classifier.expects(:brain).returns(@brain)
      end 

      should "train" do
        @brain.expects(:train).with(:x, :y).returns(:z)
        assert_equal :z, @classifier.train(:x, :y)
      end

      should "untrain" do
        @brain.expects(:untrain).with(:x, :y).returns(:z)
        assert_equal :z, @classifier.untrain(:x, :y)
      end

      should "categorize" do
        @brain.expects(:classify).with(:x).returns(:z)
        assert_equal :z, @classifier.category?(:x)
      end


    end

    should "dump brain to data on save" do
      @classifier.expects(:brain).returns(:brain)
      Marshal.expects(:dump).with(:brain).returns(:frozen_brain)
      @classifier.name = "xxxxx"
      @classifier.categories = "x y"
      @classifier.save!
      assert_equal :frozen_brain, @classifier.data
    end

  end
end
