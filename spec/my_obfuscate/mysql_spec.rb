require 'spec_helper'

describe MyObfuscate::Mysql do

  describe "#rows_to_be_inserted" do
    it "should split a mysql string into fields" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES ('bob@bob.com','bob', 'somethingelse1', 25, '2', 10,    'hi')  ;  "
      fields = [['bob@bob.com', 'bob', 'somethingelse1', '25', '2', '10', "hi"]]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work ok with escaped characters" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES ('bob,@bob.c  , om', 'bo\\', b', 'some\"thin\\gel\\\\\\'se1', 25, '2', 10,    'hi', 5)  ; "
      fields = [['bob,@bob.c  , om', 'bo\\\', b', 'some"thin\\gel\\\\\\\'se1', '25', '2', '10', "hi", "5"]]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work with multiple subinserts" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES (1,2,3, '((m))(oo()s,e'), ('bob,@bob.c  , om', 'bo\\', b', 'some\"thin\\gel\\\\\\'se1', 25, '2', 10,    'hi', 5) ;"
      fields = [["1", "2", "3", "((m))(oo()s,e"], ['bob,@bob.c  , om', 'bo\\\', b', 'some"thin\\gel\\\\\\\'se1', '25', '2', '10', "hi", "5"]]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work ok with NULL values" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES (NULL    , 'bob@bob.com','bob', NULL, 25, '2', NULL,    'hi', NULL  ); "
      fields = [[nil, 'bob@bob.com', 'bob', nil, '25', '2', nil, "hi", nil]]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work with empty strings" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES (NULL    , '', ''      , '', 25, '2','',    'hi','') ;"
      fields = [[nil, '', '', '', '25', '2', '', "hi", '']]
      subject.rows_to_be_inserted(string).should == fields
    end

    it "should work with hex encoded blobs" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES ('bla' , 'blobdata', 'blubb' , 0xACED00057372001F6A6176612E7574696C2E436F6C6C656) ;"
      fields = [['bla', 'blobdata', 'blubb', '0xACED00057372001F6A6176612E7574696C2E436F6C6C656']]
      subject.rows_to_be_inserted(string).should == fields
    end
  end

  describe "#make_valid_value_string" do
    it "should work with nil values" do
      value = nil
      subject.make_valid_value_string(value).should == 'NULL'
    end

    it "should work with hex-encoded blob data"  do
      value = "0xACED00057372001F6A6176612E7574696C2E436F6C6C656"
      subject.make_valid_value_string(value).should == '0xACED00057372001F6A6176612E7574696C2E436F6C6C656'
    end

    it "should quote hex-encoded ALIKE data"  do
      value = "40x17x7"
      subject.make_valid_value_string(value).should == "'40x17x7'"
    end

    it "should quote all other values" do
      value = "hello world"
      subject.make_valid_value_string(value).should == "'hello world'"
    end
  end

  describe "#parse_insert_statement" do
    it "should return nil for other SQL syntaxes (MS SQL Server)" do
      subject.parse_insert_statement("INSERT [dbo].[TASKS] ([TaskID], [TaskName]) VALUES (61, N'Report Thing')").should be_nil
    end

    it "should return nil for MySQL non-insert statements" do
      subject.parse_insert_statement("CREATE TABLE `some_table`;").should be_nil
    end

    it "should return a hash of table name, column names for MySQL insert statements" do
      hash = subject.parse_insert_statement("INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);")
      hash.should == {:table_name => :some_table, :column_names => [:email, :name, :something, :age]}
    end
  end

end
