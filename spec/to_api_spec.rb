require 'spec_helper'

class FakeRecord < ActiveRecord::Base
  def attributes;{};end
  def attributes_from_column_definition;[];end
  def self.columns_hash;{};end
  named_scope :scopez, :conditions => '1=1'
end

class FakeChildRecord < FakeRecord
end

describe '#to_api' do
  shared_examples_for "ignoring includes" do
    it "ignores includes" do
      lambda {instance.to_api(['bar']) }.should_not raise_exception
    end
  end

  describe Hash do

    it "returns a new hash with all values to_api'ed" do
      obj1 = stub('1', :to_api => "1 to api")
      obj2 = mock('2', :to_api => "2 to the api")

      hash = {:one => obj1, :two => obj2}
      hash.to_api.should == {
          :one => "1 to api",
          :two => "2 to the api",
      }
    end

    it "passes on includes" do
      a = "a"
      a.should_receive(:to_api).with(['bar']).and_return(:apiz)
      {:one => a}.to_api(['bar']).should == {:one => :apiz}
    end
  end

  describe String do
    it "returns self" do
      foo = "thequickbrownfoxjumpsoverthelazydog"
      foo.to_api.should == foo
    end
    describe "ingoring includes" do
      let(:instance) { "foo" }
      it_should_behave_like "ignoring includes"
    end

  end

  describe Integer do
    it "returns self" do
      foo = 8
      foo.to_api.should == foo
    end
    describe "ingoring includes" do
      let(:instance) { 8 }
      it_should_behave_like "ignoring includes"
    end

  end

  describe Symbol do
    it "returns string of sym" do
      :foo.to_api.should == "foo"
    end
    describe "ingoring includes" do
      let(:instance) { :foo }
      it_should_behave_like "ignoring includes"
    end

  end

  describe DateTime do
    it "returns db string for date time" do
      now = DateTime.parse("2001-11-28 04:01:59")
      now.to_api.should == "2001-11-28 04:01:59"
    end
    describe "ingoring includes" do
      let(:instance) { DateTime.now }
      it_should_behave_like "ignoring includes"
    end
  end

  describe Enumerable do
    class Enumz
      attr_accessor :kid
      include Enumerable
      def each
        yield @kid
      end
    end
    it "returns to_api of its kids" do
      e = Enumz.new
      e.kid = "a"
      e.kid.should_receive(:to_api).and_return(:apiz)
      [e.kid].to_api.should == [:apiz]
    end
  end

  describe ActiveRecord::NamedScope::Scope do
    it "returns to_api of its kids" do
      FakeRecord.should_receive(:reflect_on_all_associations).and_return([mock(:name => "fake_child_records")])
      @base = FakeRecord.new
      @base.should_receive(:fake_child_records).and_return([{"foo" => "bar"}])

      FakeRecord.stub!(:find_every => [@base])
      FakeRecord.scopez.to_api("fake_child_records").should == [{"fake_child_records" => [{"foo" => "bar"}]}]
    end
  end

  describe Array do
    it "returns to_api of its kids" do
      a = "a"
      a.should_receive(:to_api).and_return(:apiz)
      [a].to_api.should == [:apiz]
    end

    it "explodes on non-to_api-able kids" do
      lambda { [/boom/].to_api }.should raise_exception
    end

    it "passes on includes" do
      a = "a"
      a.should_receive(:to_api).with(['bar']).and_return(:apiz)
      [a].to_api(['bar']).should == [:apiz]
    end
  end

  describe ActiveRecord::Base do

    describe "with attributes" do
      before do
        @base = FakeRecord.new
        @base.stub!(:attributes => {"age" => mock(:to_api => :apid_age)})
      end

      it "includes the to_api'd attributes" do
        @base.to_api["age"].should == :apid_age
      end
    end

    describe "with includes" do
      before do
        @base = FakeRecord.new
        @base.stub!(:attributes => {})
        FakeRecord.stub!(:reflect_on_all_associations => [mock(:name => "foopy_pantz")])
        @base.stub!(:foopy_pantz => "pantz of foop")
      end

      it "includes the to_api'd attributes" do
        @base.to_api("foopy_pantz")["foopy_pantz"].should == "pantz of foop"
      end
      
      it "ignores non association includes" do
        @base.stub!(:yarg => "YYYYARRGG")
        @base.to_api("yarg")["yarg"].should be_nil
      end
      
      it "allows for explicitly declaring allowable includes" do
        @base.stub!(:foo => "FOO")
        @base.stub!(:valid_api_includes => ["foo"])
        @base.to_api("foo")["foo"].should == "FOO"
      end
      
      describe "versions of params" do
      
        before do
          FakeChildRecord.stub!(:reflect_on_all_associations => [mock(:name => "foopy_pantz")])
          @child = FakeChildRecord.new
          @child.stub!(:foopy_pantz => "pantz of foop")
  
          FakeRecord.should_receive(:reflect_on_all_associations).and_return([mock(:name => "fake_child_records"), mock(:name => "other_relation")])  
          @base = FakeRecord.new
          
          @base.should_receive(:fake_child_records).and_return([@child])
          @other_child = mock(:to_api => {"foo"=>"bar"})
        end
        
        it "only passes includes to the correct objects" do
          @child.should_receive(:to_api).with().and_return({})
          @base.to_api("fake_child_records","foopy_pantz").should == {"fake_child_records" => [{}]}
        end
        
        
        it "takes a single arg" do
          @child.should_receive(:to_api).with().and_return({})
          @base.to_api("fake_child_records").should == {"fake_child_records" => [{}]}
        end
        
        it "takes array with singles" do
          @child.should_receive(:to_api).with().and_return({})
          @base.to_api("fake_child_records","foopy_pantz").should == {"fake_child_records" => [{}]}
        end
        
        it "takes array with subhash" do
          @child.should_receive(:to_api).with("foopy_pantz").and_return({})
          @base.should_receive(:other_relation).and_return(@other_child)
          @base.to_api({"fake_child_records" => "foopy_pantz"}, "other_relation").should == {"fake_child_records" => [{}], "other_relation" => {"foo"=>"bar"}}
        end
        
        it "takes array with singles and subhashes" do
          @child.should_receive(:to_api).with("foopy_pantz").and_return({})
          @base.to_api("fake_child_records" => "foopy_pantz").should == {"fake_child_records" => [{}]}
        end
      end
    end

  end
end
