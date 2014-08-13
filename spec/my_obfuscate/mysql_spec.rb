require 'spec_helper'

describe MyObfuscate::Mysql do

  describe "#rows_to_be_inserted" do
    it "should split a mysql string into fields" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES ('bob@bob.com','bob', 'somethingelse1', 25, '2', 10,    'hi')  ;  "
      fields = [['bob@bob.com', 'bob', 'somethingelse1', '25', '2', '10', "hi"]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work ok with escaped characters" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES ('bob,@bob.c  , om', 'bo\\', b', 'some\"thin\\gel\\\\\\'se1', 25, '2', 10,    'hi', 5)  ; "
      fields = [['bob,@bob.c  , om', 'bo\\\', b', 'some"thin\\gel\\\\\\\'se1', '25', '2', '10', "hi", "5"]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work with multiple subinserts" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES (1,2,3, '((m))(oo()s,e'), ('bob,@bob.c  , om', 'bo\\', b', 'some\"thin\\gel\\\\\\'se1', 25, '2', 10,    'hi', 5) ;"
      fields = [["1", "2", "3", "((m))(oo()s,e"], ['bob,@bob.c  , om', 'bo\\\', b', 'some"thin\\gel\\\\\\\'se1', '25', '2', '10', "hi", "5"]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work ok with NULL values" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES (NULL    , 'bob@bob.com','bob', NULL, 25, '2', NULL,    'hi', NULL  ); "
      fields = [[nil, 'bob@bob.com', 'bob', nil, '25', '2', nil, "hi", nil]]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work with empty strings" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES (NULL    , '', ''      , '', 25, '2','',    'hi','') ;"
      fields = [[nil, '', '', '', '25', '2', '', "hi", '']]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end

    it "should work with hex encoded blobs" do
      string = "INSERT INTO `some_table` (thing1,thing2) VALUES ('bla' , 'blobdata', 'blubb' , 0xACED00057372001F6A6176612E7574696C2E436F6C6C656) ;"
      fields = [['bla', 'blobdata', 'blubb', '0xACED00057372001F6A6176612E7574696C2E436F6C6C656']]
      expect(subject.rows_to_be_inserted(string)).to eq(fields)
    end
  end

  describe "#make_valid_value_string" do
    it "should work with nil values" do
      value = nil
      expect(subject.make_valid_value_string(value)).to eq('NULL')
    end

    it "should work with hex-encoded blob data"  do
      value = "0xACED00057372001F6A6176612E7574696C2E436F6C6C656"
      expect(subject.make_valid_value_string(value)).to eq('0xACED00057372001F6A6176612E7574696C2E436F6C6C656')
    end

    it "should quote hex-encoded ALIKE data"  do
      value = "40x17x7"
      expect(subject.make_valid_value_string(value)).to eq("'40x17x7'")
    end

    it "should quote all other values" do
      value = "hello world"
      expect(subject.make_valid_value_string(value)).to eq("'hello world'")
    end
  end

  describe "#parse_insert_statement" do
    it "should return nil for other SQL syntaxes (MS SQL Server)" do
      expect(subject.parse_insert_statement("INSERT [dbo].[TASKS] ([TaskID], [TaskName]) VALUES (61, N'Report Thing')")).to be_nil
    end

    it "should return nil for MySQL non-insert statements" do
      expect(subject.parse_insert_statement("CREATE TABLE `some_table`;")).to be_nil
    end

    it "should return a hash of table name, column names for MySQL insert statements" do
      hash = subject.parse_insert_statement("INSERT INTO `some_table` (`email`, `name`, `something`, `age`) VALUES ('bob@honk.com','bob', 'some\\'thin,ge())lse1', 25),('joe@joe.com','joe', 'somethingelse2', 54);")
      expect(hash).to eq({:table_name => :some_table, :column_names => [:email, :name, :something, :age]})
    end
  end

end
