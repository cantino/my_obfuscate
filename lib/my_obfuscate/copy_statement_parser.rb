class MyObfuscate
  module CopyStatementParser

    # Postgres uses COPY statements instead of INSERT and look like:
    #
    #   COPY some_table (a, b, c, d) FROM stdin;
    #   1	2	3	4
    #   5	6	7	8
    #   \.
    #
    # This requires the parse methods to persist data (table name and
    # column names) across multiple lines.
    #
    def parse(obfuscator, config, input_io, output_io)
      current_table_name, current_columns = ""
      inside_copy_statement = false
      inside_function = false
      function_body_symbol = nil

      input_io.each do |line|
        if parse_function_statement(line)
          inside_function = true
        end

        if inside_function
          if start_func_body = /AS (\$.*\$)$/.match(line)
            function_body_symbol = start_func_body[1]
          elsif function_body_symbol && /#{Regexp.escape function_body_symbol};$/.match(line) && line.include?(function_body_symbol)
            inside_function = false
            function_body_symbol = nil
          end

          output_io.write line
        elsif parse_insert_statement(line)
          raise RuntimeError.new("Cannot obfuscate Postgres dumps containing INSERT statements. Please use COPY statments.")
        elsif table_data = parse_copy_statement(line)
          inside_copy_statement = true

          current_table_name = table_data[:table_name]
          current_columns = table_data[:column_names]

          if !config[current_table_name]
            $stderr.puts "Deprecated: #{current_table_name} was not specified in the config.  A future release will cause this to be an error.  Please specify the table definition or set it to :keep."
          end

          output_io.write line
        elsif line.match /\S*\.\n/
          inside_copy_statement = false

          output_io.write line
        elsif inside_copy_statement
          output_io.puts obfuscator.obfuscate_bulk_insert_line(line, current_table_name, current_columns)
        else
          output_io.write line
        end
      end
    end

  end
end
