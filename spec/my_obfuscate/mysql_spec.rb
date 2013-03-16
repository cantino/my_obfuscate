require 'spec_helper'
require 'my_obfuscate/database_helper_shared_examples'

describe MyObfuscate::Mysql do

  it_behaves_like MyObfuscate::DatabaseHelperShared

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
