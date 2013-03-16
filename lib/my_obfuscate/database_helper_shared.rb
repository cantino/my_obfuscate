class MyObfuscate
  module DatabaseHelperShared

    def rows_to_be_inserted(line)
      line = line.gsub(insert_regex, '').gsub(/\s*;\s*$/, '')
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
      length = string.length
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
            fields << current_field unless current_field.nil?
            current_field = nil
            in_quoted_string = false
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
      end

      fields << current_field unless current_field.nil?
      output << fields unless fields.length == 0
      output
    end

  end
end
