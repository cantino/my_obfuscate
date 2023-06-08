class MyObfuscate
  class Postgres
    include MyObfuscate::CopyStatementParser
    include MyObfuscate::ConfigScaffoldGenerator

    # Copy statements contain the column values tab separated like so:
    #   blah	blah	blah	blah
    # which we want to turn into:
    #   [['blah','blah','blah','blah']]
    #
    # We wrap it in an array to keep it consistent with MySql bulk
    # obfuscation (multiple rows per insert statement)
    def rows_to_be_inserted(line)
      row = line.split(/\t/, -1)
      row.last && row.last.strip!

      row.collect! do |value|
        if value == "\\N"
          nil
        else
          value
        end
      end

      [row]
    end

    def parse_copy_statement(line)
      if regex_match = /^\s*COPY (.*?) \((.*?)\) FROM\s*/i.match(line)
        {
            :table_name   => regex_match[1].to_sym,
            :column_names => regex_match[2].split(/\s*,\s*/).map do |column|
              strip_quotes(column).to_sym
            end
        }
      end
    end

    def make_insert_statement(table_name, column_names, values, ignore = nil)
      values.join("\t")
    end

    def make_valid_value_string(value)
      if value.nil?
        "\\N"
      else
        value
      end
    end

    def parse_insert_statement(line)
      /^\s*INSERT INTO/i.match(line)
    end

    def strip_quotes(value)
      value.sub(/\A"(.*)"\Z/, '\1')
    end
  end
end
