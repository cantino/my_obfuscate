require 'spec_helper'

describe MyObfuscate::Postgres do

  let(:helper) { MyObfuscate::Postgres.new }

  describe "#rows_to_be_inserted" do
    it 'splits tab seperated values' do
      line = "1	2	3	4"
      helper.rows_to_be_inserted(line).should == [["1","2","3","4"]]
    end

    it 'ignores the newline character at the end of string' do
      line = "1	2	3	4\n"
      helper.rows_to_be_inserted(line).should == [["1","2","3","4"]]
    end

    it "doesn't ignore newlines due to empty strings" do
      line = "1	2	3	\n"
      helper.rows_to_be_inserted(line).should == [["1","2","3",""]]
    end

    it "doesn't ignore newline characters in the string" do
      line = "1	2	3\n4	5"
      helper.rows_to_be_inserted(line).should == [["1","2","3\n4","5"]]
    end

    it "preserves empty strings in the middle of the string" do
      line = "1	2		4"
      helper.rows_to_be_inserted(line).should == [["1","2","","4"]]
    end

    it "preserves newline characters in the middle of the string" do
      line = "1	2	\n	4"
      helper.rows_to_be_inserted(line).should == [["1","2","\n","4"]]
    end

    it "replaces \\N with nil" do
      line = "1	2	\\N	4"
      helper.rows_to_be_inserted(line).should == [["1","2",nil,"4"]]
    end

    it "replaces \\N\n with nil" do
      line = "1	2	3	\\N\n"
      helper.rows_to_be_inserted(line).should == [["1","2","3",nil]]
    end
  end

  describe "#parse_copy_statement" do
    it 'parses table name and column names' do
      line = "COPY some_table (id, email, name, something) FROM stdin;"
      hash = helper.parse_copy_statement(line)
      hash[:table_name].should == :some_table
      hash[:column_names].should == [:id, :email, :name, :something]
    end
  end

  describe "#make_insert_statement" do
    it 'creates a string with tab delminted' do
      helper.make_insert_statement(:some_table, [:id, :name], ['1', '2']).should == "1	2"
    end
  end
end
