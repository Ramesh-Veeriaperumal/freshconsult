require 'classifier/extensions/string'
require 'classifier/bayes'

class Helpdesk::Classifier < ActiveRecord::Base
  set_table_name "helpdesk_classifiers"

  validates_presence_of :name, :categories
  validates_uniqueness_of :name
  validates_length_of :name, :categories, :in => 1..120

  def brain
    @brain ||= data ? Marshal.load(data) : Classifier::Bayes.new(*categories.split)
  end

  def train(category, text)
    brain.train(category, text)
  end

  def untrain(category, text)   
    brain.untrain(category, text)
  end

  def category?(text)
    brain.classify(text)
  end

protected

  def before_save
    self[:data] = Marshal.dump(brain)
  end

end

