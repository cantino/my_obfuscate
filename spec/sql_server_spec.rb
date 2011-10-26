require 'spec_helper'

describe MyObfuscate::SqlServer do
  describe "#parse_insert_statement" do
    it "should return a hash of table_name, column_names for SQL Server input statements" do
      hash = subject.parse_insert_statement("INSERT [dbo].[TASKS] ([TaskID], [TaskName]) VALUES (61, N'Report Thing')")
      hash.should == { :table_name => :TASKS, :column_names => [:TaskID, :TaskName] }
    end

    it "should return nil for SQL Server non-insert statements" do
      subject.parse_insert_statement("CREATE TABLE [dbo].[WORKFLOW](").should be_nil
    end

    it "should return nil for non-SQL Server insert statements (MySQL)" do
      subject.parse_insert_statement("INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);").should be_nil
    end
  end

  describe "#rows_to_be_inserted" do
    it "should split a SQL Server string into fields" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (N'bob@bob.com',N'bob', N'somethingelse1',25, '2', 10,    'hi')  ;  "
      fields = [['bob@bob.com', 'bob', 'somethingelse1', '25', '2', '10', "hi"]]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work ok with single quote escape" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (N'bob,@bob.c  , om', 'bo'', b', N'some\"thingel''se1', 25, '2', 10,    'hi', 5)  ; "
      fields = [['bob,@bob.c  , om', "bo'', b", "some\"thingel''se1", '25', '2', '10', "hi", "5"]]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work ok with NULL values" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (NULL    , N'bob@bob.com','bob', NULL, 25, N'2', NULL,    'hi', NULL  ); "
      fields = [[nil, 'bob@bob.com', 'bob', nil, '25', '2', nil, "hi", nil]]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work with empty strings" do
      string = "INSERT [dbo].[some_table] ([thing1],[thing2]) VALUES (NULL    , N'', ''      , '', 25, '2','',    N'hi','') ;"
      fields = [[nil, '', '','', '25', '2', '', "hi", '']]
      subject.rows_to_be_inserted(string).should == fields
    end
  end
end