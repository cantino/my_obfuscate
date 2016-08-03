class MyObfuscate
  module InsertStatementParser

    def parse(obfuscator, config, input_io, output_io)
      input_io.each do |line|
        if table_data = parse_insert_statement(line)
          table_name = table_data[:table_name]
          columns = table_data[:column_names]
          ignore = table_data[:ignore]

          if config[table_name]
            obfuscator.check_for_defined_columns_not_in_table(
              table_name, columns)

            obfuscator.check_for_table_columns_not_in_definition(
              table_name, columns)

            output_io.puts obfuscator.obfuscate_bulk_insert_line(
              line, table_name, columns, ignore)
          else
            obfuscator.handle_column_mismatch("#{table_name} was not specified in the config. Please specify the table definition or set it to :keep.")
            output_io.write line
          end
        else
          output_io.write line
        end
      end
    end

  end
end


