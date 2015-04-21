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
        expect(sub_insert).to eq(@test_insert_passes.shift)
        count += 1
        sub_insert
      end
      expect(count).to eq(2)
      expect(reassembled).to eq(@test_insert)
    end
  end

  describe "#obfuscate" do

    describe "when using Postgres" do
      let(:dump) do
        StringIO.new(<<-SQL)
COPY some_table (id, email, name, something, age) FROM stdin;
1	hello	monkey	moose	14
\.

COPY single_column_table (id) FROM stdin;
1
2
\\N
\.

COPY another_table (a, b, c, d) FROM stdin;
1	2	3	4
1	2	3	4
\.

COPY some_table_to_keep (a, b) FROM stdin;
5	6
\.
        SQL
      end

      let(:obfuscator) do
        MyObfuscate.new({
          :some_table => {
            :email => {:type => :email, :skip_regexes => [/^[\w\.\_]+@honk\.com$/i, /^dontmurderme@direwolf.com$/]},
            :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
            :age => {:type => :integer, :between => 10...80, :unless => :nil },
          },
          :single_column_table => {
            :id => {:type => :integer, :between => 2..9, :unless => :nil}
          },
          :another_table => :truncate,
          :some_table_to_keep => :keep
        }).tap do |obfuscator|
          obfuscator.database_type = :postgres
        end
      end

      let(:output_string) do
        output = StringIO.new
        obfuscator.obfuscate(dump, output)
        output.rewind
        output.read
      end

      let(:scaffolder) do
        MyObfuscate.new({
            :some_other_table => {
                :email => {:type => :email, :skip_regexes => [/^[\w\.\_]+@honk\.com$/i, /^dontmurderme@direwolf.com$/]},
                :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                :age => {:type => :integer, :between => 10...80, :unless => :nil },
            },
            :single_column_table => {
                :id => {:type => :integer, :between => 2..9, :unless => :nil}
            },
            :another_table => :truncate,
            :some_table_to_keep => :keep
        }).tap do |scaffolder|
          scaffolder.database_type = :postgres
          scaffolder.globally_kept_columns = %w[age]
        end
      end

      let(:scaffold_output_string) do
        output = StringIO.new
        scaffolder.scaffold(dump, output)
        output.rewind
        output.read
      end

      it "is able to obfuscate single column tables" do
        expect(output_string).not_to include("1\n2\n")
        expect(output_string).to match(/\d\n\d\n/)
      end

      it "is able to truncate tables" do
        expect(output_string).not_to include("1\t2\t3\t4")
      end

      it "can obfuscate the tables" do
        expect(output_string).to include("COPY some_table (id, email, name, something, age) FROM stdin;\n")
        expect(output_string).to match(/1\t.*\t\S{8}\tmoose\t\d{2}\n/)
      end

      it "can skip nils" do
        expect(output_string).to match(/\d\n\d\n\\N/)
      end

      it "is able to keep tables" do
        expect(output_string).to include("5\t6")
      end

      context "when dump contains INSERT statement" do
        let(:dump) do
          StringIO.new(<<-SQL)
          INSERT INTO some_table (email, name, something, age) VALUES ('','', '', 25);
          SQL
        end

        it "raises an error if using postgres with insert statements" do
          expect { output_string }.to raise_error RuntimeError
        end
      end

      it "when there is no existing config, should scaffold all the columns that are not globally kept" do
        expect(scaffold_output_string).to match(/:email\s+=>\s+:keep.+scaffold/)
        expect(scaffold_output_string).to match(/:name\s+=>\s+:keep.+scaffold/)
      end

      it "should not scaffold a columns that is globally kept" do
        expect(scaffold_output_string).not_to match(/:age\s+=>\s+:keep.+scaffold/)
      end

    end

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
          expect(output.read).to eq(string)
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
          expect {
            @ddo.obfuscate(@database_dump, @output)
          }.to raise_error
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
                                         :c => {:type => :null},
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
          expect(@output_string).not_to include("INSERT INTO `another_table`")
          expect(@output_string).to include("INSERT INTO `one_more_table`")
        end

        it "should be able to declare tables to keep" do
          expect(@output_string).to include("INSERT INTO `some_table_to_keep` (`a`, `b`, `c`, `d`) VALUES (1,2,3,4), (5,6,7,8);")
        end

        it "should ignore tables that it doesn't know about, but should warn" do
          expect(@output_string).to include("INSERT INTO `an_ignored_table` (`col`, `col2`) VALUES ('hello','kjhjd^&dkjh'), ('hello1','kjhj!'), ('hello2','moose!!');")
          @error_output.rewind
          expect(@error_output.read).to match(/an_ignored_table was not specified in the config/)
        end

        it "should obfuscate the tables" do
          expect(@output_string).to include("INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES (")
          expect(@output_string).to include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES (")
          expect(@output_string).to include("'some\\'thin,ge())lse1'")
          expect(@output_string).to include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES ('hello','monkey',NULL),('hello1','monkey',NULL),('hello2','monkey',NULL);")
          expect(@output_string).not_to include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES ('hello','kjhjd^&dkjh', 'aawefjkafe'), ('hello1','kjhj!', 892938), ('hello2','moose!!', NULL);")
          expect(@output_string).not_to include("INSERT INTO `one_more_table` (`a`, `password`, `c`, `d,d`) VALUES ('hello','kjhjd^&dkjh','aawefjkafe'),('hello1','kjhj!',892938),('hello2','moose!!',NULL);")
          expect(@output_string).not_to include("INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);")
        end

        it "honors a special case: on the people table, rows with skip_regexes that match are skipped" do
          expect(@output_string).to include("('bob@honk.com',")
          expect(@output_string).to include("('dontmurderme@direwolf.com',")
          expect(@output_string).not_to include("joe@joe.com")
          expect(@output_string).to include("example.com")
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
          expect {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.to raise_error(/column 'something' defined/i)
        end

        it "should accept columns defined in globally_kept_columns" do
          @ddo.globally_kept_columns = %w[something]
          expect {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.not_to raise_error
        end
      end

      context "when there is an existing config to scaffold" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT IGNORE INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS}
                                     },
                                     :another_table => :truncate
                                 })
          @ddo.globally_kept_columns = %w[something]
          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should scaffold missing columns" do
          expect(@output_string).to match(/:age\s+=>\s+:keep.+scaffold/)
        end

        it "should not scaffold globally_kept_columns" do
          expect(@output_string).not_to match(/:something\s+=>\s+:keep.+scaffold/)
        end

        it "should pass through correct columns" do
          expect(@output_string).not_to match(/:email\s+=>\s+:keep.+scaffold/)
          expect(@output_string).to match(/:email\s+=>/)
          expect(@output_string).not_to match(/\#\s*:email/)
        end
      end

      context "when using :secondary_address" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO `some_table` (`email`, `name`, `something`, `age`, `address1`, `address2`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25, '221B Baker St', 'Suite 100'),('joe@joe.com','joe', 'somethingelse2', 54, '1300 Pennsylvania Ave', '2nd floor');
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :something => :keep,
                                         :age => :keep,
                                         :address1 => :street_address,
                                         :address2 => :secondary_address
                                     }})
          @output = StringIO.new
          @ddo.obfuscate(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should obfuscate address1" do
          expect(@output_string).to include("address1")
          expect(@output_string).not_to include("Baker St")
        end

        it "should obfuscate address2" do
          expect(@output_string).to include("address2")
          expect(@output_string).not_to include("Suite 100")
        end
      end

      context "when there is an existing config to scaffold" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO `some_table` (`email`, `name`, `something`, `age`, `address1`, `address2`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25, '221B Baker St', 'Suite 100'),('joe@joe.com','joe', 'somethingelse2', 54, '1300 Pennsylvania Ave', '2nd floor');
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :something => :keep,
                                         :age => :keep,
                                         :gender => {:type => :fixed, :string => "m"},
                                         :address1 => :street_address,
                                         :address2 => :secondary_address
                                     }})
          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should enumerate extra columns" do
          expect(@output_string).to match(/\#\s*:gender/)
        end
      end

      context "when there is an existing config to scaffold with both missing and extra columns" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT IGNORE INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :gender => {:type => :fixed, :string => "m"}
                                     }})
          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should scaffold missing columns" do
          expect(@output_string).to match(/:age\s+=>\s+:keep.+scaffold/)
          expect(@output_string).to match(/:something\s+=>\s+:keep.+scaffold/)
        end

        it "should enumerate extra columns" do
          expect(@output_string).to match(/\#\s*:gender/)
        end
      end

      context "when there is an existing config to scaffold and it is just right" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :something => :keep,
                                         :age => :keep
                                     }})
          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should say that everything is present and accounted for" do
          expect(@output_string).to match(/^\s*\#.*account/)
          expect(@output_string).not_to include("scaffold")
          expect(@output_string).not_to include(":some_table")
        end
      end

      context "when scaffolding a table with no existing config" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT INTO `some_table` (`email`, `name`, `something`, `age_of_the_individual_who_is_specified_by_this_row_of_the_table`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_other_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :something => :keep,
                                         :age_of_the_individual_who_is_specified_by_this_row_of_the_table => :keep
                                     }})
          @ddo.globally_kept_columns = %w[name]

          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should scaffold all the columns that are not globally kept" do
          expect(@output_string).to match(/:email\s+=>\s+:keep.+scaffold/)
          expect(@output_string).to match(/:something\s+=>\s+:keep.+scaffold/)
        end

        it "should not scaffold globally kept columns" do
          expect(@output_string).not_to match(/:name\s+=>\s+:keep.+scaffold/)
        end

        it "should preserve long column names" do
          expect(@output_string).to match(/:age_of_the_individual_who_is_specified_by_this_row_of_the_table/)
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
          expect(output.read).to eq(string)
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
          expect {
            @ddo.obfuscate(@database_dump, @output)
          }.to raise_error
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
          expect(@output_string).not_to include("INSERT [dbo].[another_table]")
          expect(@output_string).to include("INSERT [dbo].[one_more_table]")
        end

        it "should be able to declare tables to keep" do
          expect(@output_string).to include("INSERT [dbo].[some_table_to_keep] ([a], [b], [c], [d]) VALUES (1,2,3,4);")
          expect(@output_string).to include("INSERT [dbo].[some_table_to_keep] ([a], [b], [c], [d]) VALUES (5,6,7,8);")
        end

        it "should ignore tables that it doesn't know about, but should warn" do
          expect(@output_string).to include("INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello',N'kjhjd^&dkjh');")
          expect(@output_string).to include("INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello1',N'kjhj!');")
          expect(@output_string).to include("INSERT [dbo].[an_ignored_table] ([col], [col2]) VALUES (N'hello2',N'moose!!');")
          @error_output.rewind
          expect(@error_output.read).to match(/an_ignored_table was not specified in the config/)
        end

        it "should obfuscate the tables" do
          expect(@output_string).to include("INSERT [dbo].[some_table] ([email], [name], [something], [age], [bday]) VALUES (")
          expect(@output_string).to include("CAST(0x00009E1A00000000 AS DATETIME)")
          expect(@output_string).to include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (")
          expect(@output_string).to include("'some''thin,ge())lse1'")
          expect(@output_string).to include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello',N'monkey',NULL);")
          expect(@output_string).to include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello1',N'monkey',NULL);")
          expect(@output_string).to include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello2',N'monkey',NULL);")
          expect(@output_string).not_to include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello',N'kjhjd^&dkjh', N'aawefjkafe');")
          expect(@output_string).not_to include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello1',N'kjhj!', 892938);")
          expect(@output_string).not_to include("INSERT [dbo].[one_more_table] ([a], [password], [c], [d,d]) VALUES (N'hello2',N'moose!!', NULL);")
          expect(@output_string).not_to include("INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES (N'bob@honk.com',N'bob', N'some''thin,ge())lse1', 25, CAST(0x00009E1A00000000 AS DATETIME));")
          expect(@output_string).not_to include("INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES (N'joe@joe.com',N'joe', N'somethingelse2', 54, CAST(0x00009E1A00000000 AS DATETIME));")
        end

        it "honors a special case: on the people table, rows with anything@honk.com in a slot marked with :honk_email_skip do not change this slot" do
          expect(@output_string).to include("(N'bob@honk.com',")
          expect(@output_string).to include("(N'dontmurderme@direwolf.com',")
          expect(@output_string).not_to include("joe@joe.com")
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
          expect {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.to raise_error(/column 'something' defined/i)
        end

        it "should accept columns defined in globally_kept_columns" do
          @ddo.globally_kept_columns = %w[something]
          expect {
            @ddo.obfuscate(@database_dump, StringIO.new)
          }.not_to raise_error
        end
      end

      context "when there is an existing config to scaffold and it is missing columns" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES ('bob@honk.com','bob', 'some''thin,ge())lse1', 25);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS}
                                     }})
          @ddo.database_type = :sql_server
          @ddo.globally_kept_columns = %w[something]
          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should scaffold columns that can't be found" do
          expect(@output_string).to match(/:age\s+=>\s+:keep.+scaffold/)
        end

        it "should not scaffold globally_kept_columns" do
          expect(@output_string).not_to match(/:something\s+=>\s+:keep.+scaffold/)
        end
      end

      context "when there is an existing config to scaffold and it has extra columns" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES ('bob@honk.com','bob', 'some''thin,ge())lse1', 25);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :something => :keep,
                                         :age => :keep,
                                         :gender => {:type => :fixed, :string => "m"}
                                     }})
          @ddo.database_type = :sql_server

          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should enumerate extra columns" do
          expect(@output_string).to match(/\#\s*:gender/)
        end
      end

      context "when there is an existing config to scaffold and it has both missing and extra columns" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES ('bob@honk.com','bob', 'some''thin,ge())lse1', 25);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :gender => {:type => :fixed, :string => "m"}
                                     }})
          @ddo.database_type = :sql_server

          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should scaffold columns that can't be found" do
          expect(@output_string).to match(/:age\s+=>\s+:keep.+scaffold/)
          expect(@output_string).to match(/:something\s+=>\s+:keep.+scaffold/)
        end

        it "should enumerate extra columns" do
          expect(@output_string).to match(/\#\s*:gender/)
        end
      end

      context "when there is an existing config to scaffold and it is just right" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES ('bob@honk.com','bob', 'some''thin,ge())lse1', 25);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :something => :keep,
                                         :age => :keep
                                     }})
          @ddo.database_type = :sql_server

          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should say that everything is present and accounted for" do
          expect(@output_string).to match(/^\s*\#.*account/)
          expect(@output_string).not_to include("scaffold")
          expect(@output_string).not_to include(":some_table")
        end
      end

      context "when scaffolding a table with no existing config" do
        before do
          @database_dump = StringIO.new(<<-SQL)
          INSERT [dbo].[some_table] ([email], [name], [something], [age]) VALUES ('bob@honk.com','bob', 'some''thin,ge())lse1', 25);
          SQL
          @ddo = MyObfuscate.new({
                                     :some_other_table => {
                                         :email => {:type => :email, :honk_email_skip => true},
                                         :name => {:type => :string, :length => 8, :chars => MyObfuscate::USERNAME_CHARS},
                                         :something => :keep,
                                         :age => :keep
                                     }})
          @ddo.database_type = :sql_server
          @ddo.globally_kept_columns = %w[age]

          @output = StringIO.new
          @ddo.scaffold(@database_dump, @output)
          @output.rewind
          @output_string = @output.read
        end

        it "should scaffold all the columns that are not globally kept" do
          expect(@output_string).to match(/:email\s+=>\s+:keep.+scaffold/)
          expect(@output_string).to match(/:name\s+=>\s+:keep.+scaffold/)
          expect(@output_string).to match(/:something\s+=>\s+:keep.+scaffold/)
        end

        it "should not scaffold globally kept columns" do
          expect(@output_string).not_to match(/:age\s+=>\s+:keep.+scaffold/)
        end
      end

    end
  end

end
