class MyObfuscate
  class ConfigApplicator

    def self.apply_table_config(row, table_config, columns)
      return row unless table_config.is_a?(Hash)
      row_hash = row_as_hash(row, columns)

      table_config.each do |column, definition|
        index = columns.index(column)

        definition = { :type => definition } if definition.is_a?(Symbol)

        if definition.has_key?(:unless)
          unless_check = make_conditional_method(definition[:unless], index, row)

          next if unless_check.call(row_hash)
        end


        if definition.has_key?(:if)
          if_check = make_conditional_method(definition[:if], index, row)

          next unless if_check.call(row_hash)
        end

        if definition[:skip_regexes]
          next if definition[:skip_regexes].any? {|regex| row[index] =~ regex}
        end

        row[index.to_i] = case definition[:type]
          when :email
            md5 = Digest::MD5.hexdigest(rand.to_s)[0...5]
            clean_quotes("#{Faker::Internet.email}.#{md5}.example.com")
          when :string
            random_string(definition[:length] || 30, definition[:chars] || SENSIBLE_CHARS)
          when :lorem
            clean_bad_whitespace(clean_quotes(Faker::Lorem.sentences(number: definition[:number] || 1).join(" ")))
          when :like_english
            clean_quotes random_english_sentences(definition[:number] || 1)
          when :name
            clean_quotes(Faker::Name.name)
          when :first_name
            clean_quotes(Faker::Name.first_name)
          when :last_name
            clean_quotes(Faker::Name.last_name)
          when :address
            clean_quotes(Faker::Address.full_address)
          when :street_address
            clean_bad_whitespace(clean_quotes(Faker::Address.street_address))
          when :secondary_address
            clean_bad_whitespace(clean_quotes(Faker::Address.secondary_address))
          when :city
            clean_quotes(Faker::Address.city)
          when :state
            clean_quotes Faker::Address.state_abbr
          when :zip_code
            Faker::Address.zip_code
          when :phone
            clean_quotes Faker::PhoneNumber.phone_number
          when :company
            clean_bad_whitespace(clean_quotes(Faker::Company.name))
          when :ipv4
            Faker::Internet.ip_v4_address
          when :ipv6
            Faker::Internet.ip_v6_address
          when :url
            clean_bad_whitespace(Faker::Internet.url)
          when :integer
            random_integer(definition[:between] || (0..1000)).to_s
          when :fixed
            if definition[:one_of]
              definition[:one_of][(rand * definition[:one_of].length).to_i]
            else
              definition[:string].is_a?(Proc) ? definition[:string].call(row_hash) : definition[:string]
            end
          when :null
            nil
          when :keep
            row[index]
          else
            $stderr.puts "Keeping a column value by providing an unknown type (#{definition[:type]}) is deprecated.  Use :keep instead."
            row[index]
        end
      end
      row
    end

    def self.row_as_hash(row, columns)
      columns.zip(row).inject({}) {|m, (name, value)| m[name] = value; m}
    end

    def self.make_conditional_method(conditional_method, index, row)
      if conditional_method.is_a?(Symbol)
        if conditional_method == :blank
          conditional_method = lambda { |row_hash| row[index].nil? || row[index] == '' }
        elsif conditional_method == :nil
          conditional_method = lambda { |row_hash| row[index].nil? }
        end
      end
      conditional_method
    end

    def self.random_integer(between)
      (between.min + (between.max - between.min) * rand).round
    end

    def self.random_string(length_or_range, chars)
      length_or_range = (length_or_range..length_or_range) if length_or_range.is_a?(Integer)
      times = random_integer(length_or_range)
      out = ""
      times.times { out << chars[rand * chars.length] }
      out
    end

    def self.random_english_sentences(num)
      @@walker_method ||= begin
        words, counts = [], []
        File.read(File.expand_path(File.join(File.dirname(__FILE__), 'data', 'en_50K.txt'))).each_line do |line|
          word, count = line.split(/\s+/)
          words << word
          counts << count.to_i
        end
        WalkerMethod.new(words, counts)
      end

      sentences = []
      num.times do
        words = []
        (3 + rand * 5).to_i.times { words << @@walker_method.random }
        sentences << words.join(" ") + "."
        sentences.last[0] = sentences.last[0].upcase
      end
      sentences.join(" ")
    end

    def self.clean_quotes(value)
      value.gsub(/['"]/, '')
    end

    def self.clean_bad_whitespace(value)
      value.gsub(/[\n\t\r]/, '')
    end

  end
end
