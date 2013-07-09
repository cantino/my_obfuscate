require 'spec_helper'

describe MyObfuscate::ConfigApplicator do

  describe ".apply_table_config" do
    it "should work on email addresses" do
      100.times do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else"], {:a => {:type => :email}}, [:a, :b])
        new_row.length.should == 2
        new_row.first.should =~ /^[\w\.]+\@(\w+\.){2,3}[a-f0-9]{5}\.example\.com$/
      end
    end

    it "should work on strings" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "something crazy"], {:b => {:type => :string, :length => 7}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].length.should == 7
      new_row[1].should_not == "something_else"
    end

    describe "conditional directives" do
      it "should honor :unless conditionals" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => lambda { |row| row[:a] == "blah" }}}, [:a, :b, :c])
        new_row[0].should_not == "123"
        new_row[0].should == "blah"

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => lambda { |row| row[:a] == "not blah" }}}, [:a, :b, :c])
        new_row[0].should == "123"

        new_row = MyObfuscate::ConfigApplicator.apply_table_config([nil, "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => :nil}, :b=> {:type => :fixed, :string => "123", :unless => :nil}}, [:a, :b, :c])
        new_row[0].should == nil
        new_row[1].should == "123"

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(['', "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => :blank}, :b=> {:type => :fixed, :string => "123", :unless => :blank}}, [:a, :b, :c])
        new_row[0].should == ''
        new_row[1].should == "123"
      end

      it "should honor :if conditionals" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }}}, [:a, :b, :c])
        new_row[0].should == "123"

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if=> lambda { |row| row[:a] == "not blah" }}}, [:a, :b, :c])
        new_row[0].should_not == "123"
        new_row[0].should == "blah"

        new_row = MyObfuscate::ConfigApplicator.apply_table_config([nil, "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => :nil}, :b=> {:type => :fixed, :string => "123", :if => :nil}}, [:a, :b, :c])
        new_row[0].should == "123"
        new_row[1].should == "something_else"

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(['', "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => :blank}, :b=> {:type => :fixed, :string => "123", :if => :blank}}, [:a, :b, :c])
        new_row[0].should == "123"
        new_row[1].should == "something_else"
      end

      it "should supply the original row values to the conditional" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else"], {:a => {:type => :fixed, :string => "123"}, :b => {:type => :fixed, :string => "yup", :if => lambda { |row| row[:a] == "blah" }}}, [:a, :b])
        new_row[0].should == "123"
        new_row[1].should == "yup"
      end

      it "should honor combined :unless and :if conditionals" do
        #both true
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }, :unless => lambda { |row| row[:b] == "something_else" }}}, [:a, :b, :c])
        new_row[0].should == "blah"

        #both false
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "not blah" }, :unless => lambda { |row| row[:b] == "not something_else" }}}, [:a, :b, :c])
        new_row[0].should == "blah"

        #if true, #unless false
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }, :unless => lambda { |row| row[:b] == "not something_else" }}}, [:a, :b, :c])
        new_row[0].should == "123"

        #if false, #unless true
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "not blah" }, :unless => lambda { |row| row[:b] == "something_else" }}}, [:a, :b, :c])
        new_row[0].should == "blah"
      end
    end

    it "should be able to generate random integers in ranges" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:c => {:type => :integer, :between => 10..100}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[2].to_i.to_s.should == new_row[2] # It should be an integer.
      new_row[2].should_not == "5"
    end

    it "should be able to substitute fixed strings" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => "hello"}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "hello"
    end

    it "should be able to substitute a proc that returns a string" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => proc { "Hello World" }}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "Hello World"
    end

    it "should provide the row to the proc" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => proc { |a| a[:b] }}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "something_else"
    end

    it "should be able to substitute fixed strings from a random set" do
      looking_for = ["hello", "world"]
      original_looking_for = looking_for.dup
      guard = 0
      while !looking_for.empty? && guard < 1000
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => {:type => :fixed, :one_of => ["hello", "world"]}}, [:a, :b, :c])
        new_row.length.should == 3
        original_looking_for.should include(new_row[0])
        looking_for.delete new_row[0]
        guard += 1
      end
      looking_for.should be_empty
    end

    it "should treat a symbol in the column definition as an implicit { :type => symbol }" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => :null, :a => :keep}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should == "blah"
      new_row[1].should == nil
    end

    it "should be able to set things NULL" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :null}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == nil
    end

    it "should be able to :keep the value the same" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :keep}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "something_else"
    end

    it "should keep the value when given an unknown type, but should display a warning" do
      $stderr = error_output = StringIO.new
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :unknown_type}}, [:a, :b, :c])
      $stderr = STDERR
      new_row.length.should == 3
      new_row[1].should == "something_else"
      error_output.rewind
      error_output.read.should =~ /Keeping a column value by.*?unknown_type/
    end

    it "should be able to substitute lorem ipsum text" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :lorem, :b => {:type => :lorem, :number => 2}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should_not =~ /\w\.(?!\Z)/
      new_row[1].should_not == "something_else"
      new_row[1].should =~ /\w\.(?!\Z)/
    end

    it "should be able to generate an :company" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["Smith and Sons", "something_else", "5"], {:a => :company}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "Smith and Sons"
      new_row[0].should =~ /\w+/
    end

    it "should be able to generate an :url" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["http://mystuff.blogger.com", "something_else", "5"], {:a => :url}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "http://mystuff.blogger.com"
      new_row[0].should =~ /http:\/\/\w+/
    end

    it "should be able to generate an :ipv4" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["1.2.3.4", "something_else", "5"], {:a => :ipv4}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "1.2.3.4"
      new_row[0].should =~ /\d+\.\d+\.\d+\.\d+/
    end

    it "should be able to generate an :ipv6" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["fe80:0000:0000:0000:0202:b3ff:fe1e:8329", "something_else", "5"], {:a => :ipv6}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "fe80:0000:0000:0000:0202:b3ff:fe1e:8329"
      new_row[0].should =~ /[0-9a-f:]+/
    end

    it "should be able to generate an :address" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :address}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ /\d+ \w/
    end

    it "should be able to generate a :name" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :name}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ / /
    end

    it "should be able to generate just a street address" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :street_address}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ /\d+ \w/
    end

    it "should be able to generate a city" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :city}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
    end

    it "should be able to generate a state" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :state}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
    end

    it "should be able to generate a zip code" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :zip_code}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ /\d+/
    end

    it "should be able to generate a phone number" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :phone}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ /\d+/
    end

    describe "when faker generates values with quotes in them" do
      before do
        Faker::Address.stub(:city).and_return("O'ReillyTown")
        Faker::Name.stub(:name).and_return("Foo O'Reilly")
        Faker::Name.stub(:first_name).and_return("O'Foo")
        Faker::Name.stub(:last_name).and_return("O'Reilly")
        Faker::Lorem.stub(:sentences).with(any_args).and_return(["Foo bar O'Thingy"])
      end

      it "should remove single quotes from the value" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["address", "city", "first", "last", "fullname", "some text"],
                  {:a => :address, :b => :city, :c => :first_name, :d => :last_name, :e => :name, :f => :lorem},
                  [:a, :b, :c, :d, :e, :f])
        new_row.each {|value| value.should_not include("'")}
      end
    end
  end

  describe ".row_as_hash" do
    it "will map row values into a hash with column names as keys" do
      MyObfuscate::ConfigApplicator.row_as_hash([1, 2, 3, 4], [:a, :b, :c, :d]).should == {:a => 1, :b => 2, :c => 3, :d => 4}
    end
  end

  describe ".random_english_sentences" do
    before do
      File.should_receive(:read).once.and_return("hello 2")
    end

    after do
      MyObfuscate::ConfigApplicator.class_variable_set(:@@walker_method, nil)
    end

    it "should only load file data once" do
      MyObfuscate::ConfigApplicator.random_english_sentences(1)
      MyObfuscate::ConfigApplicator.random_english_sentences(1)
    end

    it "should make random sentences" do
      MyObfuscate::ConfigApplicator.random_english_sentences(2).should =~ /^(Hello( hello)+\.\s*){2}$/
    end
  end

end
