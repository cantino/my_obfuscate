require 'spec_helper'

describe MyObfuscate::ConfigApplicator do

  describe ".apply_table_config" do
    it "should work on email addresses" do
      100.times do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else"], {:a => {:type => :email}}, [:a, :b])
        expect(new_row.length).to eq(2)
        expect(new_row.first).to match(/^[\w\.]+\@(\w+\.){2,3}[a-f0-9]{5}\.example\.com$/)
      end
    end

    it "should work on strings" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "something crazy"], {:b => {:type => :string, :length => 7}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[1].length).to eq(7)
      expect(new_row[1]).not_to eq("something_else")
    end

    describe "conditional directives" do
      it "should honor :unless conditionals" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => lambda { |row| row[:a] == "blah" }}}, [:a, :b, :c])
        expect(new_row[0]).not_to eq("123")
        expect(new_row[0]).to eq("blah")

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => lambda { |row| row[:a] == "not blah" }}}, [:a, :b, :c])
        expect(new_row[0]).to eq("123")

        new_row = MyObfuscate::ConfigApplicator.apply_table_config([nil, "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => :nil}, :b=> {:type => :fixed, :string => "123", :unless => :nil}}, [:a, :b, :c])
        expect(new_row[0]).to eq(nil)
        expect(new_row[1]).to eq("123")

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(['', "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :unless => :blank}, :b=> {:type => :fixed, :string => "123", :unless => :blank}}, [:a, :b, :c])
        expect(new_row[0]).to eq('')
        expect(new_row[1]).to eq("123")
      end

      it "should honor :if conditionals" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }}}, [:a, :b, :c])
        expect(new_row[0]).to eq("123")

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if=> lambda { |row| row[:a] == "not blah" }}}, [:a, :b, :c])
        expect(new_row[0]).not_to eq("123")
        expect(new_row[0]).to eq("blah")

        new_row = MyObfuscate::ConfigApplicator.apply_table_config([nil, "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => :nil}, :b=> {:type => :fixed, :string => "123", :if => :nil}}, [:a, :b, :c])
        expect(new_row[0]).to eq("123")
        expect(new_row[1]).to eq("something_else")

        new_row = MyObfuscate::ConfigApplicator.apply_table_config(['', "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => :blank}, :b=> {:type => :fixed, :string => "123", :if => :blank}}, [:a, :b, :c])
        expect(new_row[0]).to eq("123")
        expect(new_row[1]).to eq("something_else")
      end

      it "should supply the original row values to the conditional" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else"], {:a => {:type => :fixed, :string => "123"}, :b => {:type => :fixed, :string => "yup", :if => lambda { |row| row[:a] == "blah" }}}, [:a, :b])
        expect(new_row[0]).to eq("123")
        expect(new_row[1]).to eq("yup")
      end

      it "should honor combined :unless and :if conditionals" do
        #both true
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }, :unless => lambda { |row| row[:b] == "something_else" }}}, [:a, :b, :c])
        expect(new_row[0]).to eq("blah")

        #both false
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "not blah" }, :unless => lambda { |row| row[:b] == "not something_else" }}}, [:a, :b, :c])
        expect(new_row[0]).to eq("blah")

        #if true, #unless false
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "blah" }, :unless => lambda { |row| row[:b] == "not something_else" }}}, [:a, :b, :c])
        expect(new_row[0]).to eq("123")

        #if false, #unless true
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a=> {:type => :fixed, :string => "123", :if => lambda { |row| row[:a] == "not blah" }, :unless => lambda { |row| row[:b] == "something_else" }}}, [:a, :b, :c])
        expect(new_row[0]).to eq("blah")
      end
    end

    it "should be able to generate random integers in ranges" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:c => {:type => :integer, :between => 10..100}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[2].to_i.to_s).to eq(new_row[2]) # It should be an integer.
      expect(new_row[2]).not_to eq("5")
    end

    it "should be able to substitute fixed strings" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => "hello"}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[1]).to eq("hello")
    end

    it "should be able to substitute a proc that returns a string" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => proc { "Hello World" }}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[1]).to eq("Hello World")
    end

    it "should provide the row to the proc" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :fixed, :string => proc { |a| a[:b] }}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[1]).to eq("something_else")
    end

    it "should be able to substitute fixed strings from a random set" do
      looking_for = ["hello", "world"]
      original_looking_for = looking_for.dup
      guard = 0
      while !looking_for.empty? && guard < 1000
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => {:type => :fixed, :one_of => ["hello", "world"]}}, [:a, :b, :c])
        expect(new_row.length).to eq(3)
        expect(original_looking_for).to include(new_row[0])
        looking_for.delete new_row[0]
        guard += 1
      end
      expect(looking_for).to be_empty
    end

    it "should treat a symbol in the column definition as an implicit { :type => symbol }" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => :null, :a => :keep}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).to eq("blah")
      expect(new_row[1]).to eq(nil)
    end

    it "should be able to set things NULL" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :null}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[1]).to eq(nil)
    end

    it "should be able to :keep the value the same" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :keep}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[1]).to eq("something_else")
    end

    it "should keep the value when given an unknown type, but should display a warning" do
      $stderr = error_output = StringIO.new
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:b => {:type => :unknown_type}}, [:a, :b, :c])
      $stderr = STDERR
      expect(new_row.length).to eq(3)
      expect(new_row[1]).to eq("something_else")
      error_output.rewind
      expect(error_output.read).to match(/Keeping a column value by.*?unknown_type/)
    end

    it "should be able to substitute lorem ipsum text" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :lorem, :b => {:type => :lorem, :number => 2}}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
      expect(new_row[0]).not_to match(/\w\.(?!\Z)/)
      expect(new_row[1]).not_to eq("something_else")
      expect(new_row[1]).to match(/\w\.(?!\Z)/)
    end

    context 'when asked to generate English-like text' do
      after do
        MyObfuscate::ConfigApplicator.class_variable_set(:@@walker_method, nil)
      end

      context 'with the default dictionary' do
        before do
          expect(File).to receive(:read).once do |filename|
            expect(filename).not_to be_nil

            "hello 2"
          end
        end

        let(:new_row) do
          MyObfuscate::ConfigApplicator.apply_table_config(
            ['blah', 'something_else', '5'],
            {
              :a => :keep,
              :b => {
                :type   => :like_english,
                :number => 2
              }
            },
            [:a, :b, :c])
        end

        it 'should be able to generate and substitute English-like text' do
          expect(new_row.length).to eq(3)

          expect(new_row[0]).to eq("blah")

          expect(new_row[1]).not_to eq('something_else')
          expect(new_row[1]).to match(/^(Hello( hello)+\.\s*){2}$/)

          expect(new_row[2]).to eq('5')
        end
      end

      context 'with a custom dictionary' do
        before do
          expect(File)
            .to receive(:read).with('custom.txt').once
            .and_return("custom 2")
        end

        let(:new_row) do
          MyObfuscate::ConfigApplicator.apply_table_config(
            ['blah', 'something_else', '5'],
            {
              :a => :keep,
              :b => {
                :type   => :like_english,
                :number => 2,
                :dictionary => 'custom.txt'
              }
            },
            [:a, :b, :c])
        end

        it 'should be able to use the dictionary to generate and substitute English-like text' do
          expect(new_row.length).to eq(3)

          expect(new_row[0]).to eq("blah")

          expect(new_row[1]).not_to eq('something_else')
          expect(new_row[1]).to match(/^(Custom( custom)+\.\s*){2}$/)

          expect(new_row[2]).to eq('5')
        end
      end
    end

    it "should be able to generate an :company" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["Smith and Sons", "something_else", "5"], {:a => :company}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("Smith and Sons")
      expect(new_row[0]).to match(/\w+/)
    end

    it "should be able to generate an :url" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["http://mystuff.blogger.com", "something_else", "5"], {:a => :url}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("http://mystuff.blogger.com")
      expect(new_row[0]).to match(/http:\/\/\w+/)
    end

    it "should be able to generate an :ipv4" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["1.2.3.4", "something_else", "5"], {:a => :ipv4}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("1.2.3.4")
      expect(new_row[0]).to match(/\d+\.\d+\.\d+\.\d+/)
    end

    it "should be able to generate an :ipv6" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["fe80:0000:0000:0000:0202:b3ff:fe1e:8329", "something_else", "5"], {:a => :ipv6}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("fe80:0000:0000:0000:0202:b3ff:fe1e:8329")
      expect(new_row[0]).to match(/[0-9a-f:]+/)
    end

    it "should be able to generate an :address" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :address}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
      expect(new_row[0]).to match(/\d+ \w/)
    end

    it "should be able to generate a :name" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :name}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
      expect(new_row[0]).to match(/ /)
    end

    it "should be able to generate just a street address" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :street_address}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
      expect(new_row[0]).to match(/\d+ \w/)
    end

    it "should be able to generate a city" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :city}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
    end

    it "should be able to generate a state" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :state}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
    end

    it "should be able to generate a zip code" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :zip_code}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
      expect(new_row[0]).to match(/\d+/)
    end

    it "should be able to generate a phone number" do
      new_row = MyObfuscate::ConfigApplicator.apply_table_config(["blah", "something_else", "5"], {:a => :phone}, [:a, :b, :c])
      expect(new_row.length).to eq(3)
      expect(new_row[0]).not_to eq("blah")
      expect(new_row[0]).to match(/\d+/)
    end

    describe "when faker generates values with quotes in them" do
      before do
        allow(FFaker::Address).to receive(:city).and_return("O'ReillyTown")
        allow(FFaker::Name).to receive(:name).and_return("Foo O'Reilly")
        allow(FFaker::Name).to receive(:first_name).and_return("O'Foo")
        allow(FFaker::Name).to receive(:last_name).and_return("O'Reilly")
        allow(FFaker::Lorem).to receive(:sentences).with(any_args).and_return(["Foo bar O'Thingy"])
      end

      it "should remove single quotes from the value" do
        new_row = MyObfuscate::ConfigApplicator.apply_table_config(["address", "city", "first", "last", "fullname", "some text"],
                  {:a => :address, :b => :city, :c => :first_name, :d => :last_name, :e => :name, :f => :lorem},
                  [:a, :b, :c, :d, :e, :f])
        new_row.each {|value| expect(value).not_to include("'")}
      end
    end
  end

  describe ".row_as_hash" do
    it "will map row values into a hash with column names as keys" do
      expect(MyObfuscate::ConfigApplicator.row_as_hash([1, 2, 3, 4], [:a, :b, :c, :d])).to eq({:a => 1, :b => 2, :c => 3, :d => 4})
    end
  end

  describe ".random_english_sentences" do
    after do
      MyObfuscate::ConfigApplicator.class_variable_set(:@@walker_method, nil)
    end

    context 'when using the default dictionary' do
      before do
        expect(File)
          .to receive(:read).once
          .and_return("hello 2")
      end

      it "should only load file data once" do
        MyObfuscate::ConfigApplicator.random_english_sentences(1)

        # Second call should not call File.read; if it does, the `before`
        # expectation will fail
        MyObfuscate::ConfigApplicator.random_english_sentences(1)
      end

      it "should make random sentences" do
        expect(MyObfuscate::ConfigApplicator.random_english_sentences(2))
          .to match(/^(Hello( hello)+\.\s*){2}$/)
      end
    end

    context 'when using a custom dictionary' do
      before do
        expect(File)
          .to receive(:read).once.with('custom_file.txt')
          .and_return("custom 2")
      end

      it "should only load file data once" do
        MyObfuscate::ConfigApplicator.random_english_sentences(
          1,
          dictionary: 'custom_file.txt')

        # Second call should not call File.read; if it does, the `before`
        # expectation will fail
        MyObfuscate::ConfigApplicator.random_english_sentences(
          1,
          dictionary: 'custom_file.txt')
      end

      it "should make random sentences using the custom words" do
        sentences =
          MyObfuscate::ConfigApplicator.random_english_sentences(
            2, dictionary: 'custom_file.txt')

        expect(sentences).to match(/^(Custom( custom)+\.\s*){2}$/)
      end
    end
  end

end
