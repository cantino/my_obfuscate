class MyObfuscate
  module DatabaseHelperShared

    def partial_insert_regex
      /^\s*INSERT/i
    end

    def values_regex
      /VALUES\s*(.*);/im
    end

    def rows_to_be_inserted(line)
      line = values_regex.match(line)[1]
      context_aware_mysql_string_split(line)
    end

    def make_valid_value_string(value)
      if value.nil?
        "NULL"
      elsif value =~ /^0x[0-9a-fA-F]+$/
        value
      else
        "'" + value + "'"
      end
    end

    # Be aware, strings must be quoted in single quotes!
    def context_aware_mysql_string_split(string)
      in_sub_insert = false
      in_quoted_string = false
      escaped = false
      current_field = nil
      current_field_quote_count = 0
      length = string.length
      index = 0
      fields = []
      output = []

      string.each_char do |i|
        if escaped
          escaped = false
          current_field ||= ""
          current_field << i
        else
          if i == "\\"
            escaped = true
            current_field ||= ""
            current_field << i
          elsif i == "(" && !in_quoted_string && !in_sub_insert
            in_sub_insert = true
          elsif i == ")" && !in_quoted_string && in_sub_insert
            fields << current_field unless current_field.nil?
            output << fields unless fields.length == 0
            in_sub_insert = false
            fields = []
            current_field = nil
          elsif i == "'" && !in_quoted_string
            fields << current_field unless current_field.nil?
            current_field = ''
            in_quoted_string = true
          elsif i == "'" && in_quoted_string
            if string[index+1] == i
              current_field << i
              current_field_quote_count += 1
            elsif string[index-1] == i && current_field_quote_count.odd?
              current_field << i
              current_field_quote_count += 1
            else
              fields << current_field unless current_field.nil?
              current_field = nil
              in_quoted_string = false
              current_field_quote_count = 0
            end
          elsif i == "," && !in_quoted_string && in_sub_insert
            fields << current_field unless current_field.nil?
            current_field = nil
          elsif i == "L" && !in_quoted_string && in_sub_insert && current_field == "NUL"
            current_field = nil
            fields << current_field
          elsif (i == " " || i == "\t") && !in_quoted_string
            # Don't add whitespace not in a string
          elsif in_sub_insert
            current_field ||= ""
            current_field << i
          end
        end
        index += 1
      end

      fields << current_field unless current_field.nil?
      output << fields unless fields.length == 0
      output
    end

  end
end
