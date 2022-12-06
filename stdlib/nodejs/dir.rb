# await: true

::JS.npm_dependency "glob", "7.1.3"

class Dir
  @__glob__ = ::JS.dynimport('glob').__await__
  @__fs__ = ::JS.dynimport('fs').__await__
  @__path__ = ::JS.dynimport('path').__await__
  @__os__ = ::JS.dynimport('os').__await__
  `var __glob__ = #{@__glob__}`
  `var __fs__ = #{@__fs__}`
  `var __path__ = #{@__path__}`
  `var __os__ = #{@__os__}`

  class << self
    def [](glob)
      `__glob__.sync(#{glob})`
    end

    def pwd
      `process.cwd().split(__path__.sep).join(__path__.posix.sep)`
    end

    def home
      `__os__.homedir()`
    end

    def chdir(path)
      `process.chdir(#{path})`
    end

    def mkdir(path)
      `__fs__.mkdirSync(#{path})`
    end

    def entries(dirname)
      %x{
        var result = [];
        var entries = __fs__.readdirSync(#{dirname});
        for (var i = 0, ii = entries.length; i < ii; i++) {
          result.push(entries[i]);
        }
        return result;
      }
    end

    def glob(pattern)
      pattern = [pattern] unless pattern.respond_to? :each
      pattern.flat_map do |subpattern|
        subpattern = subpattern.to_path if subpattern.respond_to? :to_path
        subpattern = ::Opal.coerce_to!(subpattern, String, :to_str)
        `__glob__.sync(subpattern)`
      end
    end

    alias getwd pwd
  end
end
