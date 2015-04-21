class MyObfuscate
  module InsertStatementParser

    def parse(obfuscator, config, input_io, output_io)
      input_io.each do |line|
        if table_data = parse_insert_statement(line)
          table_name = table_data[:table_name]
          columns = table_data[:column_names]
          ignore = table_data[:ignore]
          if config[table_name]
            output_io.puts obfuscator.obfuscate_bulk_insert_line(line, table_name, columns, ignore)
          else
            $stderr.puts "Deprecated: #{table_name} was not specified in the config.  A future release will cause this to be an error.  Please specify the table definition or set it to :keep."
            output_io.write line
          end
        else
          output_io.write line
        end
      end
    end

  end
end


