require 'rubygems'
require 'rake'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

begin
  require 'spec/rake/spectask'
  desc 'Run unit tests'
  Spec::Rake::SpecTask.new(:test) do |t|
    t.spec_files = FileList.new('spec/**/*_spec.rb')
  end
rescue LoadError
  task :test do
    STDERR.puts "You must have rspec >= 1.2.9 to run the tests"
  end
end

desc 'Generate documentation for config_object.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.options << '--title' << 'ConfigObject' << '--line-numbers' << '--inline-source' << '--main' << 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
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
    gem.files = FileList["lib/**/*", "spec/**/*", "README.rdoc", "Rakefile"].to_a
    gem.has_rdoc = true
    gem.extra_rdoc_files = ["README.rdoc"]
    
    gem.add_development_dependency('rspec', '>= 1.2.9')
    gem.add_development_dependency('jeweler')
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
end