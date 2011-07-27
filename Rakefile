require 'rubygems'
require 'rake'

desc 'Default: run unit tests.'
task :default => :test

begin
  require 'rspec'
  require 'rspec/core/rake_task'
  desc 'Run the unit tests'
  RSpec::Core::RakeTask.new(:test)
rescue LoadError
  task :test do
    STDERR.puts "You must have rspec 2.0 installed to run the tests"
  end
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "config_object"
    gem.summary = %Q{Simple and powerful configuration library}
    gem.description = %Q{A configuration gem which is simple to use but full of awesome features.}
    gem.email = "brian@embellishedvisions.com"
    gem.homepage = "http://github.com/bdurand/config_object"
    gem.authors = ["Brian Durand"]
    gem.files = FileList["lib/**/*", "spec/**/*", "README.rdoc", "Rakefile", "MIT-LICENSE"].to_a
    gem.has_rdoc = true
    gem.extra_rdoc_files = ["README.rdoc", "MIT_LICENSE"]
    
    gem.add_development_dependency('rspec', '>=2.0.0')
    gem.add_development_dependency('jeweler')
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
end