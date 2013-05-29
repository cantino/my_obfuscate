class MyObfuscate
  class Postgres
    include MyObfuscate::DatabaseHelperShared

    def parse_insert_statement(line)
      if regex_match = insert_regex.match(line)
        {
            :table_name => regex_match[1].to_sym,
            :column_names => regex_match[2].split(/\s*,\s*/).map(&:to_sym)
        }
      end
    end

    def make_insert_statement(table_name, column_names, values_strings)
      "INSERT INTO #{table_name} (#{column_names.join(', ')}) VALUES #{values_strings};"
    end

    def insert_regex
      /^\s*INSERT INTO (.*?) \((.*?)\) VALUES.*;.*/im
    end

  end
end
