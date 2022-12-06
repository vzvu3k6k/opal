# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'opal/os'

module Opal
  # This module is included into Builder, provides abstracted data about a new
  # paradigm of compiling Opal applications into a directory.
  module BuilderDirectory
    # Output method #compile_to_directory depends on a directory compiler
    # option being set, so that imports are generated correctly.
    def compile_to_directory(dir, with_source_map: true)
      index = []
      npm_dependencies = []

      processed.each do |file|
        compiled_source = file.to_s
        compiled_source += "\n" + file.source_map.to_data_uri_comment if with_source_map

        module_name = Compiler.module_name(file.filename)

        filename = "#{dir}/#{module_name}.#{output_extension}"
        FileUtils.mkdir_p(File.dirname(filename))
        File.binwrite(filename, compiled_source)

        index << module_name if file.options[:load] || !file.options[:requirable]

        npm_dependencies += file.npm_dependencies if file.respond_to? :npm_dependencies
      end

      compile_index(dir, index)
      compile_npm(dir, npm_dependencies)
    end

    # Generates executable index files
    def compile_index(dir, index)
      index = index.map { |i| "./#{i}.#{output_extension}" }

      if !esm?
        File.binwrite("#{dir}/index.js", index.map { |i| "require(#{i.to_json});" }.join("\n") + "\n")
      else
        File.binwrite("#{dir}/index.mjs", index.map { |i| "import #{i.to_json};" }.join("\n") + "\n")

        html = <<~HTML
          <!doctype html>
          <html>
          <head>
            <meta charset='utf-8'>
            <title>Opal application</title>
          </head>
          <body>
            #{if esm?
                index.map { |i| "<script type='module' src='#{i}'></script>" }.join("\n  ")
              else
                index.map { |i| "<script src='#{i}'></script>" }.join("\n  ")
              end}
          </body>
          </html>
        HTML

        File.binwrite("#{dir}/index.html", html)
      end
    end

    # Generates package.json and runs `npm i` afterwards
    def compile_npm(dir, npm_dependencies)
      npm = {}
      npm[:private] = true
      npm[:dependencies] = {}
      npm[:type] = "module"
      npm[:main] = "./index.#{output_extension}"

      npm_dependencies.each do |name, version|
        npm[:dependencies][name] = version
      end

      File.binwrite("#{dir}/package.json", JSON.dump(npm))

      unless npm_dependencies.empty?
        system *OS.bash_c("pushd #{OS.shellescape dir}",
                          "npm i",
                          "popd")
      end
    end
  end
end
