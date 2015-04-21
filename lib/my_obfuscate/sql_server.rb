class MyObfuscate
  class SqlServer
    include MyObfuscate::InsertStatementParser
    include MyObfuscate::ConfigScaffoldGenerator

    def parse_insert_statement(line)
      if regex_match = insert_regex.match(line)
        {
            :table_name => regex_match[1].to_sym,
            :column_names => regex_match[2].split(/\]\s*,\s*\[/).map { |col| col.gsub(/[\[\]]/, "").to_sym }
        }
      end
    end

    def rows_to_be_inserted(line)
      line = line.gsub(insert_regex, '').gsub(/\s*;?\s*$/, '').gsub(/^\(/, '').gsub(/\)$/, '')
      context_aware_sql_server_string_split(line)
    end

    def make_valid_value_string(value)
      if value.nil?
        "NULL"
      elsif value.match(/^[A-Z]+\(.*?\)$/)
        value
      else
        "N'#{value}'"
      end
    end

    def make_insert_statement(table_name, column_names, values, ignore = nil)
      values_strings = values.collect do |values|
        "(" + values.join(",") + ")"
      end.join(",")

      "INSERT [dbo].[#{table_name}] ([#{column_names.join("], [")}]) VALUES #{values_strings};"
    end

    private

    def insert_regex
      /^\s*INSERT (?:INTO )?\[dbo\]\.\[(.*?)\] \((.*?)\) VALUES\s*/i
    end

    def context_aware_sql_server_string_split(string)
      in_quoted_string = false
      backslash_escape = false
      previous_char_single_quote = false
      current_field_value = nil
      completed_fields = []

      string.each_char do |char|
        if char == "'" && !in_quoted_string
          if current_field_value != "N"
            completed_fields << current_field_value unless current_field_value.nil?
          end
          current_field_value = ""
          in_quoted_string = true
        elsif previous_char_single_quote
          previous_char_single_quote = false
          if char == "'"
            current_field_value << "''"
          else
            completed_fields << current_field_value unless current_field_value.nil?
            in_quoted_string = false
            current_field_value = nil
          end
        elsif char == "'" && in_quoted_string
          previous_char_single_quote = true
        elsif char == "," && !in_quoted_string
          completed_fields << current_field_value unless current_field_value.nil?
          current_field_value = nil
        elsif char == "L" && !in_quoted_string && current_field_value == "NUL"
          current_field_value = nil
          completed_fields << current_field_value
        elsif (char == " " || char == "\t") && !in_quoted_string
          if !current_field_value.nil? && current_field_value.start_with?("CAST(")
            current_field_value << char
          end
          # Don't add whitespace not in a string
        else
          current_field_value ||= ""
          current_field_value << char
        end
      end

      completed_fields << current_field_value unless current_field_value.nil?
      [completed_fields]
    end
  end
end
