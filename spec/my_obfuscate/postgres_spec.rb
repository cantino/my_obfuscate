require 'spec_helper'

describe MyObfuscate::Postgres do

  let(:helper) { MyObfuscate::Postgres.new }

  describe "#rows_to_be_inserted" do
    it 'splits tab seperated values' do
      line = "1	2	3	4"
      helper.rows_to_be_inserted(line).should == [["1","2","3","4"]]
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
