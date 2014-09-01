require 'test_helper'

class Account < ActiveRecord::Base
  has_features do
    feature :archive_reports, :requires => [:archive, :reports]
    feature :ssl, :protected => true
    feature :archive
    feature :reports
  end
end

class FeaturesTest < ActiveSupport::TestCase
  fixtures :accounts, :features
  
  test "that features can be created" do
    a = Account.create(:name => 'name')
    assert(a.features.empty?)
    assert(!a.features.archive?)
    assert(a.features.archive.create)
    assert(a.features.size == 1)
    assert(a.features.archive?)
    assert(a.features.archive.id == a.features.archive.create.id)
  end

  test "that features can be destroyed" do
    a = accounts(:account1)
    assert(a.features.archive?)
    assert(a.features.archive.destroy)
    a.features.reload
    assert(!a.features.archive?)
  end

  test "checks for features" do
    a = accounts(:account1)
    assert(a.features.archive?)
    assert(a.features.ssl?)
    assert(!a.features.reports?)
  end
  
  test "validates feature requirements" do
    a = accounts(:account1)
    assert(a.features.reports.available?)
    assert(!a.features.archive_reports.available?)
    
    assert_raises Features::RequirementsError do
      a.features.archive_reports.create
    end
    
    assert(a.features.reports.create)
    assert(a.features.archive_reports.create)
  end
  
  test "destroys dependant features when destroyed" do
    a = accounts(:account1)
    assert(a.features.reports.create)
    assert(a.features.archive_reports.create)
    
    assert(a.features.archive.destroy)
    a.features.reload
    assert(!a.features.archive?)
    assert(!a.features.archive_reports?)
    assert(a.features.reports?)
  end
  
  test "mass updating should update features" do
    a = Account.create(:name => 'name')
    assert(a.features.empty?)
    assert(!a.features.archive?)
    assert(!a.features.reports?)
    
    a.update_attributes(:features => {:archive => '1', :reports => '1'})
    assert(a.features.archive?)
    assert(a.features.reports?)
    
    a.update_attributes(:features => {:archive => '0', :reports => '0'})
    assert(!a.features.archive?)
    assert(!a.features.reports?)
  end
  
  test "mass updating should not update protected features" do
    a = Account.create(:name => 'name')
    assert(a.features.empty?)
    assert(!a.features.archive?)
    assert(!a.features.ssl?)
    
    a.update_attributes(:features => {:archive => '1', :ssl => '1'})
    assert(a.features.archive?)
    assert(!a.features.ssl?)
    
    assert(a.features.ssl.create)
    assert(a.features.ssl?)
    a.update_attributes(:features => {:archive => '0', :ssl => '0'})
    assert(!a.features.archive?)
    assert(a.features.ssl?)
  end
end
