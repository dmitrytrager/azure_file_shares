require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[rubocop spec]

desc "Run console"
task :console do
  sh "bin/console"
end

namespace :doc do
  desc "Generate documentation"
  task :generate do
    begin
      require "yard"
      YARD::Rake::YardocTask.new do |task|
        task.files = [ "lib/**/*.rb" ]
        task.options = [ "--no-private", "--title", "Azure File Shares Documentation" ]
      end
      Rake::Task["yard"].invoke
    rescue LoadError
      puts "YARD is not available. Install it with: gem install yard"
    end
  end
end
