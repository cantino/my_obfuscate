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

      input_io.each do |line|
        if parse_insert_statement(line)
          raise RuntimeError.new("Cannot obfuscate Postgres dumps containing INSERT statements. Please use COPY statments.")
        elsif table_data = parse_copy_statement(line)
          inside_copy_statement = true

          current_table_name = table_data[:table_name]
          current_columns = table_data[:column_names]

          if !config[current_table_name]
            $stderr.puts "Deprecated: #{current_table_name} was not specified in the config.  A future release will cause this to be an error.  Please specify the table definition or set it to :keep."
          end

          output_io.write line
        elsif line.match /\\\.\n/
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
