require 'spec_helper'

describe MyObfuscate do
  describe "MyObfuscate.reassembling_each_insert" do
    before do
      @column_names = [:a, :b, :c, :d]
      @test_insert = "INSERT INTO `some_table` (`a`, `b`, `c`, `d`) VALUES ('(\\'bob@bob.com','b()ob','some(thingelse1','25)('),('joe@joe.com','joe','somethingelse2','54');"
      @test_insert_passes = [
          ["(\\'bob@bob.com", "b()ob", "some(thingelse1", "25)("],
          ["joe@joe.com", "joe", "somethingelse2", "54"]
      ]
    end

    it "should yield each subinsert and reassemble the result" do
      count = 0
      reassembled = MyObfuscate.new.reassembling_each_insert(@test_insert, "some_table", @column_names) do |sub_insert|
        sub_insert.should == @test_insert_passes.shift
        count += 1
        sub_insert
      end
      count.should == 2
      reassembled.should == @test_insert
    end
  end

  describe "MyObfuscate.apply_table_config" do
    it "should work on email addresses" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else"], {:a => {:type => :email}}, [:a, :b])
      new_row.length.should == 2
      new_row.first.should =~ /^\w+\@\w+\.\w+$/
    end

    it "should work on strings" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "something crazy"], {:b => {:type => :string, :length => 7}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].length.should == 7
      new_row[1].should_not == "something_else"
    end

    describe "conditional directives" do
      it "should honor :unless conditionals" do
        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => lambda { |row| row[:a] == "blah" }}}, [:a, :b, :c])
        new_row[0].should_not == "123"
        new_row[0].should == "blah"

        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => lambda { |row| row[:a] == "not blah" }}}, [:a, :b, :c])
        new_row[0].should == "123"

        new_row = MyObfuscate.apply_table_config([nil, "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => :nil}, :b=> {:type => :fixed, :string => "123", :unless => :nil}}, [:a, :b, :c])
        new_row[0].should == nil
        new_row[1].should == "123"

        new_row = MyObfuscate.apply_table_config(['', "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => :blank}, :b=> {:type => :fixed, :string => "123", :unless => :blank}}, [:a, :b, :c])
        new_row[0].should == ''
        new_row[1].should == "123"
      end

      it "should honor :if conditionals" do
        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }}}, [:a, :b, :c])
        new_row[0].should == "123"

        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if=> lambda { |row| row[:a] == "not blah" }}}, [:a, :b, :c])
        new_row[0].should_not == "123"
        new_row[0].should == "blah"

        new_row = MyObfuscate.apply_table_config([nil, "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => :nil}, :b=> {:type => :fixed, :string => "123", :if => :nil}}, [:a, :b, :c])
        new_row[0].should == "123"
        new_row[1].should == "something_else"

        new_row = MyObfuscate.apply_table_config(['', "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => :blank}, :b=> {:type => :fixed, :string => "123", :if => :blank}}, [:a, :b, :c])
        new_row[0].should == "123"
        new_row[1].should == "something_else"
      end

      it "should supply the original row values to the conditional" do
        new_row = MyObfuscate.apply_table_config(["blah", "something_else"], {:a => {:type => :fixed, :string => "123"}, :b => {:type => :fixed, :string => "yup", :if => lambda { |row| row[:a] == "blah" }}}, [:a, :b])
        new_row[0].should == "123"
        new_row[1].should == "yup"
      end

      it "should honor combined :unless and :if conditionals" do
        #both true
        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }, :unless => lambda { |row| row[:b] == "something_else" }}}, [:a, :b, :c])
        new_row[0].should == "blah"

        #both false
        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "not blah" }, :unless => lambda { |row| row[:b] == "not something_else" }}}, [:a, :b, :c])
        new_row[0].should == "blah"

        #if true, #unless false
        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }, :unless => lambda { |row| row[:b] == "not something_else" }}}, [:a, :b, :c])
        new_row[0].should == "123"

        #if false, #unless true
        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "not blah" }, :unless => lambda { |row| row[:b] == "something_else" }}}, [:a, :b, :c])
        new_row[0].should == "blah"
      end
    end

    it "should be able to generate random integers in ranges" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:c => {:type => :integer, :between => 10..100}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[2].to_i.to_s.should == new_row[2] # It should be an integer.
      new_row[2].should_not == "5"
    end

    it "should be able to substitute fixed strings" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => "hello"}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "hello"
    end

    it "should be able to substitute a proc that returns a string" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => proc { "Hello World" }}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "Hello World"
    end

    it "should provide the row to the proc" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => proc { |a| a[:b] }}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "something_else"
    end

    it "should be able to substitute fixed strings from a random set" do
      looking_for = ["hello", "world"]
      original_looking_for = looking_for.dup
      guard = 0
      while !looking_for.empty? && guard < 1000
        new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => {:type => :fixed, :one_of => ["hello", "world"]}}, [:a, :b, :c])
        new_row.length.should == 3
        original_looking_for.should include(new_row[0])
        looking_for.delete new_row[0]
        guard += 1
      end
      looking_for.should be_empty
    end

    it "should treat a symbol in the column definition as an implicit { :type => symbol }" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:b => :null, :a => :keep}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should == "blah"
      new_row[1].should == nil
    end

    it "should be able to set things NULL" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :null}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == nil
    end

    it "should be able to :keep the value the same" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :keep}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[1].should == "something_else"
    end

    it "should keep the value when given an unknown type, but should display a warning" do
      $stderr = error_output = StringIO.new
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :unknown_type}}, [:a, :b, :c])
      $stderr = STDERR
      new_row.length.should == 3
      new_row[1].should == "something_else"
      error_output.rewind
      error_output.read.should =~ /Keeping a column value by.*?unknown_type/
    end

    it "should be able to substitute lorem ipsum text" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :lorem, :b => {:type => :lorem, :number => 2}}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should_not =~ /\w\.(?!\Z)/
      new_row[1].should_not == "something_else"
      new_row[1].should =~ /\w\.(?!\Z)/
    end

    it "should be able to generate an :address" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :address}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ /\d+ \w/
    end

    it "should be able to generate a :name" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :name}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ / /
    end

    it "should be able to generate just a street address" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :street_address}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ /\d+ \w/
    end

    it "should be able to generate a city" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :city}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
    end

    it "should be able to generate a state" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :state}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
    end

    it "should be able to generate a zip code" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :zip_code}, [:a, :b, :c])
      new_row.length.should == 3
      new_row[0].should_not == "blah"
      new_row[0].should =~ /\d+/
    end

    it "should be able to generate a phone number" do
      new_row = MyObfuscate.apply_table_config(["blah", "something_else", "5"], {:a => :phone}, [:a, :b, :c])
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
        new_row = MyObfuscate.apply_table_config(["address", "city", "first", "last", "fullname", "some text"],
                  {:a => :address, :b => :city, :c => :first_name, :d => :last_name, :e => :name, :f => :lorem},
                  [:a, :b, :c, :d, :e, :f])
        new_row.each {|value| value.should_not include("'")}
      end
    end
  end

  describe "MyObfuscate.row_as_hash" do
    it "will map row values into a hash with column names as keys" do
      MyObfuscate.row_as_hash([1, 2, 3, 4], [:a, :b, :c, :d]).should == {:a => 1, :b => 2, :c => 3, :d => 4}
    end
  end

  describe "#obfuscate" do
    describe "when using MySQL" do
      context "when there is nothing to obfuscate" do
        it "should accept an IO object for input and output, and copy the input to the output" do
          ddo = MyObfuscate.new
          string = "hello, world\nsup?"
          input = StringIO.new(string)
          output = StringIO.new
          ddo.obfuscate(input, output)
          input.rewind
          output.rewind
          output.read.should == string
        end
      end

      context "when the dump to obfuscate is missing columns" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :gender => {:type => :fixed, :string => "m"}
                                     }})
          @output = StringIO.new
        end

        it "should raise an error if a column name can't be found" do
          lambda {
            @ddo.obfuscate(@database_dump, @output)
          }.should raise_error
        end
      end

      context "when there is something to obfuscate" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54),('dontmurderme@direwolf.com','direwolf', 'somethingelse3', 44);
          INSERT INTO `another_table` (`a`, `b`, `c`, `d`) VALUES (1,2,3,4), (5,6,7,8);
          INSERT INTO `some_table_to_keep` (`a`, `b`, `c`, `d`) VALUES (1,2,3,4), (5,6,7,8);
          INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES ('hello','kjhjd^&dkjh', 'aawefjkafe'), ('hello1','kjhj!', 892938), ('hello2','moose!!', NULL);
          INSERT INTO `an_ignored_table` (`col`, `col2`) VALUES ('hello','kjhjd^&dkjh'), ('hello1','kjhj!'), ('hello2','moose!!');
          SQL

          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :skip_regexes => [/^[\w\.\_]+@honk\.com$/i, /^dontmurderme@direwolf.com$/]},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :age => {:type => :integer, :between => 10...80}
                                     },
                                     :another_table => :truncate,
                                     :some_table_to_keep => :keep,
                                     :one_more_table => {
                                         # Note: fixed strings must be pre-SQL escaped!
                                         :password => {:type => :fixed, :string => "monkey"},
                                         :c => {:type => :null}
                                     }
                                 })
          @output = StringIO.new
          $stderr = @error_output = StringIO.new
          @ddo.obfuscate(@database_dump, @output)
          $stderr = STDERR
          @output.rewind
          @output_string = @output.read
        end

        it "should be able to truncate tables" do
          @output_string.should_not include("INSERT INTO `another_table`")
          @output_string.should include("INSERT INTO `one_more_table`")
        end

        it "should be able to declare tables to keep" do
          @output_string.should include("INSERT INTO `some_table_to_keep` (`a`, `b`, `c`, `d`) VALUES (1,2,3,4), (5,6,7,8);")
        end

        it "should ignore tables that it doesn't know about, but should warn" do
          @output_string.should include("INSERT INTO `an_ignored_table` (`col`, `col2`) VALUES ('hello','kjhjd^&dkjh'), ('hello1','kjhj!'), ('hello2','moose!!');")
          @error_output.rewind
          @error_output.read.should =~ /an_ignored_table was not specified in the config/
        end

        it "should obfuscate the tables" do
          @output_string.should include("INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES (")
          @output_string.should include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES (")
          @output_string.should include("'some\\'thin,ge())lse1'")
          @output_string.should include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES ('hello','monkey',NULL),('hello1','monkey',NULL),('hello2','monkey',NULL);")
          @output_string.should_not include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES ('hello','kjhjd^&dkjh', 'aawefjkafe'), ('hello1','kjhj!', 892938), ('hello2','moose!!', NULL);")
          @output_string.should_not include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES ('hello','kjhjd^&dkjh','aawefjkafe'),('hello1','kjhj!',892938),('hello2','moose!!',NULL);")
          @output_string.should_not include("INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);")
        end

        it "honors a special case: on the people table, rows with anything@honk.com in a slot marked with :honk_email_skip do not change this slot" do
          @output_string.should include("('bob@honk.com',")
          @output_string.should include("('dontmurderme@direwolf.com',")
          @output_string.should_not include("joe@joe.com")
        end
      end

      context "when fail_on_unspecified_columns is set to true" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54),('dontmurderme@direwolf.com','direwolf', 'somethingelse3', 44);
          SQL

          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :skip_regexes => [/^[\w\.\_]+@honk\.com$/i, /^dontmurderme@direwolf.com$/]},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :age => {:type => :integer, :between => 10...80}
                                     }
                                 })
          @ddo.fail_on_unspecified_columns = true
        end

        it "should raise an exception when an unspecified column is found" do
          lambda {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.should raise_error(/column 'something' defined/i)
        end

        it "should accept columns defined in globally_kept_columns" do
          @ddo.globally_kept_columns = %w[something]
          lambda {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.should_not raise_error
        end
      end
    end

    describe "when using MS SQL Server" do
      context "when there is nothing to obfuscate" do
        it "should accept an IO object for input and output, and copy the input to the output" do
          ddo = MyObfuscate.new
          ddo.database_type = :sql_server
          string = "hello, world\nsup?"
          input = StringIO.new(string)
          output = StringIO.new
          ddo.obfuscate(input, output)
          input.rewind
          output.rewind
          output.read.should == string
        end
      end

      context "when the dump to obfuscate is missing columns" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES ('bob@honk.com','bob', 'some''thin,ge())lse1', 25);
          SQL
          @ddo =  MyObfuscate.new({
              :some_table => {
                  :email => {:type => :email, :honk_email_skip => true},
                  :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                  :gender => {:type => :fixed, :string => "m"}
              }})
          @ddo.database_type = :sql_server
          @output = StringIO.new
        end

        it "should raise an error if a column name can't be found" do
          lambda {
            @ddo.obfuscate(@database_dump, @output)
          }.should raise_error
        end
      end

      context "when there is something to obfuscate" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT [dbo].[some_table] ([email], [name], [something], [age], [bday]) VALUES (N'bob@honk.com',N'bob', N'some''thin,ge())lse1', 25, CAST(0x00009E1A00000000 AS DATETIME));
          INSERT [dbo].[some_table] ([email], [name], [something], [age], [bday]) VALUES (N'joe@joe.com',N'joe', N'somethingelse2', 54, CAST(0x00009E1A00000000 AS DATETIME));
          INSERT [dbo].[some_table] ([email], [name], [something], [age], [bday]) VALUES (N'dontmurderme@direwolf.com',N'direwolf', N'somethingelse3', 44, CAST(0x00009E1A00000000 AS DATETIME));
          INSERT [dbo].[another_table] ([a], [b], [c], [d]) VALUES (1,2,3,4);
          INSERT [dbo].[another_table] ([a], [b], [c], [d]) VALUES (5,6,7,8);
          INSERT [dbo].[some_table_to_keep] ([a], [b], [c], [d]) VALUES (1,2,3,4);
          INSERT [dbo].[some_table_to_keep] ([a], [b], [c], [d]) VALUES (5,6,7,8);
          INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello',N'kjhjd^&dkjh', N'aawefjkafe');
          INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello1',N'kjhj!', 892938);
          INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello2',N'moose!!', NULL);
          INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello',N'kjhjd^&dkjh');
          INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello1',N'kjhj!');
          INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello2',N'moose!!');
          SQL

          @ddo = MyObfuscate.new({
               :some_table => {
                   :email => {:type => :email, :skip_regexes => [/^[\w\.\_]+@honk\.com$/i, /^dontmurderme@direwolf.com$/]},
                   :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                   :age => {:type => :integer, :between => 10...80},
                   :bday => :keep
               },
               :another_table => :truncate,
               :some_table_to_keep => :keep,
               :one_more_table => {
                   # Note: fixed strings must be pre-SQL escaped!
                   :password => {:type => :fixed, :string => "monkey"},
                   :c => {:type => :null}
               }
           })
          @ddo.database_type = :sql_server

          @output = StringIO.new
          $stderr = @error_output = StringIO.new
          @ddo.obfuscate(@database_dump, @output)
          $stderr = STDERR
          @output.rewind
          @output_string = @output.read
        end

        it "should be able to truncate tables" do
          @output_string.should_not include("INSERT [dbo].[another_table]")
          @output_string.should include("INSERT [dbo].[one_more_table]")
        end

        it "should be able to declare tables to keep" do
          @output_string.should include("INSERT [dbo].[some_table_to_keep] ([a], [b], [c], [d]) VALUES (1,2,3,4);")
          @output_string.should include("INSERT [dbo].[some_table_to_keep] ([a], [b], [c], [d]) VALUES (5,6,7,8);")
        end

        it "should ignore tables that it doesn't know about, but should warn" do
          @output_string.should include("INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello',N'kjhjd^&dkjh');")
          @output_string.should include("INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello1',N'kjhj!');")
          @output_string.should include("INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello2',N'moose!!');")
          @error_output.rewind
          @error_output.read.should =~ /an_ignored_table was not specified in the config/
        end

        it "should obfuscate the tables" do
          @output_string.should include("INSERT [dbo].[some_table] ([email], [name], [something], [age], [bday]) VALUES (")
          @output_string.should include("CAST(0x00009E1A00000000 AS DATETIME)")
          @output_string.should include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (")
          @output_string.should include("'some''thin,ge())lse1'")
          @output_string.should include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello',N'monkey',NULL);")
          @output_string.should include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello1',N'monkey',NULL);")
          @output_string.should include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello2',N'monkey',NULL);")
          @output_string.should_not include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello',N'kjhjd^&dkjh', N'aawefjkafe');")
          @output_string.should_not include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello1',N'kjhj!', 892938);")
          @output_string.should_not include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello2',N'moose!!', NULL);")
          @output_string.should_not include("INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES (N'bob@honk.com',N'bob', N'some''thin,ge())lse1', 25, CAST(0x00009E1A00000000 AS DATETIME));")
          @output_string.should_not include("INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES (N'joe@joe.com',N'joe', N'somethingelse2', 54, CAST(0x00009E1A00000000 AS DATETIME));")
        end

        it "honors a special case: on the people table, rows with anything@honk.com in a slot marked with :honk_email_skip do not change this slot" do
          @output_string.should include("(N'bob@honk.com',")
          @output_string.should include("(N'dontmurderme@direwolf.com',")
          @output_string.should_not include("joe@joe.com")
        end
      end

      context "when fail_on_unspecified_columns is set to true" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO [dbo].[some_table] ([email], [name], [something], [age]) VALUES ('bob@honk.com','bob', 'some''thin,ge())lse1', 25);
          SQL

          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :skip_regexes => [/^[\w\.\_]+@honk\.com$/i, /^dontmurderme@direwolf.com$/]},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :age => {:type => :integer, :between => 10...80}
                                     }
                                 })
          @ddo.database_type = :sql_server
          @ddo.fail_on_unspecified_columns = true
        end

        it "should raise an exception when an unspecified column is found" do
          lambda {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.should raise_error(/column 'something' defined/i)
        end

        it "should accept columns defined in globally_kept_columns" do
          @ddo.globally_kept_columns = %w[something]
          lambda {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.should_not raise_error
        end
      end
    end
  end
end