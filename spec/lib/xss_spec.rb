require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

describe "XssTermination" do
  before :all do
    activerecord_migration = ActiveRecord::Migration
    activerecord_migration.verbose = false
    activerecord_migration.create_table :xss_terminations do |t|
      t.string :field1
      t.text :field2
      t.integer :field3
    end
  end

  after :all do
    activerecord_migration = ActiveRecord::Migration
    activerecord_migration.verbose = false
    activerecord_migration.drop_table :xss_terminations
  end

  before :each do
    XssTermination.delete_all
  end

  class XssTermination < ActiveRecord::Base
    
  end

  describe ".xss_sanitizer" do
    context "with only option" do
      it "should get a plain text" do
        perform = {:only => [:field1,:field2]}
        XssTermination.xss_sanitize(perform)
        xss_terminate = XssTermination.new(:field1 => "<hello>hii</hello>hello",:field2 => "<hello>hii</hello>hello")
        xss_terminate.save
        XssTermination.first.field1.should eql "hiihello"
        XssTermination.first.field2.should eql "hiihello"
      end
      it "should sanitize both the field when sanitize option is passed" do
        perform = {:only => [:field1,:field2], :html_sanitize => [:field1,:field2] }
        XssTermination.xss_sanitize(perform)
        xss_terminate = XssTermination.new(:field1 => "<hello>hii</hello>hello<div></div>",:field2 => "<hello>hii<script>alert(\"hi\")</hello>hello")
        xss_terminate.save!
        XssTermination.first.field1.should eql "hiihello<div></div>"
        XssTermination.first.field2.should eql "hiialert(\"hi\")&lt;/hello&gt;hello"
      end
      it "should sanitize only one of the field when sanitize option is passed" do
        perform = {:only => [:field1,:field2], :html_sanitize => [:field1] }
        XssTermination.xss_sanitize(perform)
        xss_terminate = XssTermination.new(:field1 => "<hello>hii</hello><div>",:field2 => "<hello>hii<script>alert(\"hi\")</hello>hello")
        xss_terminate.save!
        XssTermination.first.field1.should eql "hii<div></div>"
        XssTermination.first.field2.should eql "hiialert(\"hi\")hello"
      end
    end

    context "with except option " do
      it "{:except => [:field1]} should return a plain text for other fields" do
        perform = {:except => [:field1]}
        XssTermination.xss_sanitize(perform)
        xss_terminate = XssTermination.new(:field1 => "<hello>hii</hello>hello<div></div>",:field2 => "<hello>hii<script><script>alert(\"hi\")</hello>hello</script></script>")
        xss_terminate.save!
        XssTermination.first.field1.should eql "<hello>hii</hello>hello<div></div>"
        XssTermination.first.field2.should eql "hiialert(\"hi\")hello"
      end
      it "{:except => [:field1]} should return a sanitized text for other fields" do
        perform = {:except => [:field1],:html_sanitize => [:field1,:field2]}
        XssTermination.xss_sanitize(perform)
        xss_terminate = XssTermination.new(:field1 => "<hello>hii</hello>hello<div></div>",:field2 => "<hello>hii<script>alert(\"hi\")</hello>hello")
        xss_terminate.save!
        XssTermination.first.field1.should eql "<hello>hii</hello>hello<div></div>"
        XssTermination.first.field2.should eql "hiialert(\"hi\")&lt;/hello&gt;hello"
      end
    end

    context "full sanitization when a new record is created" do
      it "{:except => [:field1],:full_sanitizer => [:field1,:field2]} full sanitize field2" do
        perform = {:except => [:field1],:full_sanitizer => [:field1,:field2]}
        XssTermination.xss_sanitize(perform)
        xss_terminate = XssTermination.new(:field1 => "<hello>hii</hello>hello<div></div>",:field2 => "<hello>hii<script>alert(\"hi\")</hello>hello")
        xss_terminate.save!
        XssTermination.first.field1.should eql "<hello>hii</hello>hello<div></div>"
        XssTermination.first.field2.should eql "&lt;hello&gt;hii&lt;script&gt;alert(&quot;hi&quot;)&lt;/hello&gt;hello"
        XssTermination.first.update_attributes(:field1 =>"this is only to test")
        XssTermination.first.field1.should eql "this is only to test"
        XssTermination.first.field2.should eql "&lt;hello&gt;hii&lt;script&gt;alert(&quot;hi&quot;)&lt;/hello&gt;hello"
      end
    end
  end

end
