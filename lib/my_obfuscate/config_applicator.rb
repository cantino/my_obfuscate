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
            clean_quotes("#{FFaker::Internet.email}.#{md5}.example.com")
          when :string
            random_string(definition[:length] || 30, definition[:chars] || SENSIBLE_CHARS)
          when :lorem
            clean_bad_whitespace(clean_quotes(FFaker::Lorem.sentences(definition[:number] || 1).join(".  ")))
          when :like_english
            clean_quotes random_english_sentences(definition[:number] || 1, dictionary: (definition[:dictionary] || nil))
          when :name
            clean_quotes(FFaker::Name.name)
          when :first_name
            clean_quotes(FFaker::Name.first_name)
          when :last_name
            clean_quotes(FFaker::Name.last_name)
          when :address
            clean_quotes("#{FFaker::AddressUS.street_address}\\n#{FFaker::AddressUS.city}, #{FFaker::AddressUS.state_abbr} #{FFaker::AddressUS.zip_code}")
          when :street_address
            clean_bad_whitespace(clean_quotes(FFaker::AddressUS.street_address))
          when :secondary_address
            clean_bad_whitespace(clean_quotes(FFaker::AddressUS.secondary_address))
          when :city
            clean_quotes(FFaker::AddressUS.city)
          when :state
            clean_quotes FFaker::AddressUS.state_abbr
          when :zip_code
            FFaker::AddressUS.zip_code
          when :phone
            clean_quotes FFaker::PhoneNumber.phone_number
          when :company
            clean_bad_whitespace(clean_quotes(FFaker::Company.name))
          when :ipv4
            FFaker::Internet.ip_v4_address
          when :ipv6
            # Inlined from FFaker because ffaker doesn't have ipv6.
            @@ip_v6_space ||= (0..65535).to_a
            container = (1..8).map{ |_| @@ip_v6_space.sample }
            container.map{ |n| n.to_s(16) }.join(':')
          when :url
            clean_bad_whitespace(FFaker::Internet.http_url)
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
      length_or_range = (length_or_range..length_or_range) if length_or_range.is_a?(Fixnum)
      times = random_integer(length_or_range)
      out = ""
      times.times { out << chars[rand * chars.length] }
      out
    end

    def self.random_english_sentences(num, dictionary: nil)
      dictionary_path = (dictionary || default_dictionary_path)

      @@walker_method ||= {}
      @@walker_method[dictionary_path] ||= begin
        words, counts = [], []

        File.read(dictionary_path).each_line do |line|
          word, count = line.split(/\s+/)
          words << word
          counts << count.to_i
        end

        WalkerMethod.new(words, counts)
      end

      word_list = @@walker_method[dictionary_path]

      sentences = []
      num.times do
        words = []
        (3 + rand * 5).to_i.times { words << word_list.random }
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

    def self.default_dictionary_path
      File.expand_path(File.join(File.dirname(__FILE__), 'data', 'en_50K.txt'))
    end
  end
end
