class MyObfuscate::Mysql
  INSERT_REGEX = /^\s*INSERT INTO `(.*?)` \((.*?)\) VALUES\s*/i

  def parse_insert_statement(line)
    if regex_match = INSERT_REGEX.match(line)
      {
          :table_name => regex_match[1].to_sym,
          :column_names => regex_match[2].split(/`\s*,\s*`/).map { |col| col.gsub('`', "").to_sym }
      }
    end
  end

  def rows_to_be_inserted(line)
    line = line.gsub(INSERT_REGEX, '').gsub(/\s*;\s*$/, '')
    context_aware_mysql_string_split(line)
  end

  def make_valid_value_string(value)
    if value.nil?
      "NULL"
    else
      "'" + value + "'"
    end
  end

  def make_insert_statement(table_name, column_names, values_strings)
    "INSERT INTO `#{table_name}` (`#{column_names.join('`, `')}`) VALUES #{values_strings};"
  end

  private

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