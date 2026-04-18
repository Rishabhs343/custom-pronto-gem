# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

module Fixtures
  SMELLY_CODE = <<~RUBY
    # frozen_string_literal: true

    class Offender
      def calculate(a, b, c, d, e, f)
        result = a + b + c + d + e + f
        result = a + b + c + d + e + f
        result = a + b + c + d + e + f
        result
      end
    end
  RUBY

  CLEAN_CODE = <<~RUBY
    # frozen_string_literal: true

    module Greeting
      module_function

      def hello(name)
        "Hello, \#{name}"
      end
    end
  RUBY

  def with_ruby_file(content, filename: 'subject.rb')
    Dir.mktmpdir('pronto-rubycritic-') do |dir|
      file = File.join(dir, filename)
      File.write(file, content)
      yield dir, file
    end
  end

  def with_git_repo
    Dir.mktmpdir('pronto-rubycritic-git-') do |dir|
      Dir.chdir(dir) do
        system('git', 'init', '--quiet', out: File::NULL, err: File::NULL)
        system('git', 'config', 'user.email', 'test@example.com', out: File::NULL)
        system('git', 'config', 'user.name',  'Test',             out: File::NULL)
      end
      yield dir
    end
  end
end

RSpec.configure { |c| c.include Fixtures }
