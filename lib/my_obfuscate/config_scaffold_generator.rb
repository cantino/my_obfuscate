class MyObfuscate
  module ConfigScaffoldGenerator

    def generate_config(obfuscator, config, input_io, output_io)
      input_io.each do |line|
        if obfuscator.database_type == :postgres
          table_data = parse_copy_statement(line)
        else
          table_data = parse_insert_statement(line)
        end
        next unless table_data

        table_name = table_data[:table_name]
        next if obfuscator.scaffolded_tables[table_name]    # only process each table_name once

        columns = table_data[:column_names]
        table_config = config[table_name]
        next if table_config == :truncate || table_config == :keep

        missing_columns = obfuscator.missing_column_list(table_name, columns)
        extra_columns = obfuscator.extra_column_list(table_name, columns)

        if missing_columns.count == 0 && extra_columns.count == 0
          # all columns are accounted for
          output_io.puts "\n# All columns in the config for #{table_name.upcase} are present and accounted for."
        else
          # there are columns missing (or perhaps the whole table is missing); show a scaffold
          emit_scaffold(table_name, table_config, extra_columns, missing_columns, output_io)
        end

        # Now that this table_name has been processed, remember it so we don't scaffold it again
        obfuscator.scaffolded_tables[table_name] = 1
      end
    end

    def config_table_open(table_name)
      "\n  :#{table_name} => {"
    end

    def config_table_close(table_name)
      "  },"
    end

    def emit_scaffold(table_name, existing_config, extra_columns, columns_to_scaffold, output_io)

      # header block: contains table name and any existing config
      if existing_config
        output_io.puts config_table_open(table_name)
        existing_config.each do |column, definition|
          break if extra_columns.include?(column)
          output_io.puts formatted_line(column, definition)
        end
      end

      extra_columns.each do |column|
        output_string = formatted_line(column, existing_config[column], "# unreferenced config")
        output_io.puts "#  #{output_string}"
      end

      # scaffold block: contains any config that's not already present
      output_io.puts config_table_open(table_name) unless existing_config

      scaffold = columns_to_scaffold.map do |column|
        formatted_line(column, ":keep", "# scaffold")
      end.join("\n").chomp(',')
      output_io.puts scaffold
      output_io.puts config_table_close(table_name)
    end

    def formatted_line(column, definition, comment = nil)
      if column.length < 40
        "    :#{'%-40.40s' % column}  => #{definition},   #{comment}"
      else
        "    :#{column} => #{definition},  #{comment}"
      end

    end

  end
end


