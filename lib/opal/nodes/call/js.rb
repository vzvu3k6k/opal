# frozen_string_literal: true

require 'opal/nodes/call'
require 'json'

module Opal
  module Nodes
    class CallNode
      # calls a block with arguments given to a called macro
      def argumentize(args = arglist, &block)
        args.children.map do |arg|
          argumentize_single(arg)
        end.tap do |argumentized|
          if block_given?
            if argumentized.last.is_a? Hash
              argumentized = argumentized.dup
              kwargs = argumentized.pop
            else
              kwargs = {}
            end

            return yield *argumentized, **kwargs
          end
        end
      end

      def argumentize_single(arg)
        case arg.type
        when :str, :sym, :int, :float
          arg.children.first
        when :nil
          nil
        when :true
          true
        when :false
          false
        when :array
          argumentize(arg)
        when :hash
          arg.children.map do |pair|
            error "Only pairs are supported" unless pair.type == :pair
            [argumentize_single(pair.children[0]), argumentize_single(pair.children[1])]
          end.to_h
        else
          error "Type #{arg.type} is not supported for an argumentized macro"
        end
      end

      # Adds an `import` statement and returns a value
      # glob = ::JS.import("glob", :default)
      #
      # The `what` argument denotes what do we want to import. For ESM:
      # - `:default`       => import _internal from "x" (default value)
      # - `:*`             => import * as _internal from "x"
      # - `:none`          => import "x";
      # - `:anything_else` => import { anything_else as _internal } from "x"
      # For CJS:
      # - `:default`       => require("x") (default value)
      # - `:*`             => require("x")
      # - `:none`          => require("x")
      # - `:anything_else` => require("x")["anything_else"]
      add_special :import, const: :JS do |compile_default|
        argumentize do |from, what=:default|
          compiler.imports << [from, what, from.start_with?("./")]
          push "Opal.imports[#{"#{from}/#{what}".to_json}]"
        end
      end

      # Adds a dynamic `import` statement and returns a value
      # # await: true
      # glob = ::JS.dynimport("glob", :default).__await__
      #
      # Warning - this may (or may not!) return a Promise, you need to manually await it!
      #
      # The `what` argument denotes what do we want to import. For ESM:
      # - `:default`       => import("x").then(_mod => _mod.default) (default value)
      # - `:*`             => import("x")
      # - `:none`          => import("x").then(() => nil)
      # - `:anything_else` => import("x").then(_mod => _mod.anything_else)
      # For CJS:
      # (mode of operation the same as for regular import)
      add_special :dynimport, const: :JS do |compile_default|
        argumentize do |from, what=:default|
          if compiler.esm?
            case what
            when :default
              push("import(#{from.to_json}).then(_mod => _mod.default)")
            when :*
              push("import(#{from.to_json})")
            when :none
              push("import(#{from.to_json}).then(() => nil)")
            else
              push("import(#{from.to_json}).then(_mod => _mod[#{what.to_json}])")
            end
          else
            case what
            when :default, :*
              push("require(#{from.to_json})")
            when :none
              push("(require(#{from.to_json}),nil)")
            else
              push("require(#{from.to_json})[#{what.to_json}]")
            end
          end
        end
      end

      # TODO
      add_special :export, const: :JS do |compile_default|
      end

      # root directory denotes the root directory of our compiled program
      # ::JS.npm_dependency("glob", "7.1.3", map: {"glob" => "node_modules/glob/glob.js"})
      add_special :npm_dependency, const: :JS do |compile_default|
        argumentize do |name, version = "latest", **kwargs|
          compiler.npm_dependencies << [name, version, kwargs]
          push 'nil'
        end
      end
    end
  end
end
