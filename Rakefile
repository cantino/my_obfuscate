require 'rubygems'
require 'rake'


# When updating:
#  rake version:bump:minor
#  rake gemspec
#  rake build
#  rake rubyforge:release
# Then git checkin and commit

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "my_obfuscate"
    gem.summary = %Q{Standalone Ruby code for the selective rewriting of MySQL dumps in order to protect user privacy.}
    gem.description = %Q{Standalone Ruby code for the selective rewriting of MySQL dumps in order to protect user privacy.}
    gem.email = "andrew@pivotallabs.com"
    gem.homepage = "http://github.com/honkster/myobfuscate"
    gem.authors = ["Andrew Cantino", "Dave Willett", "Mike Grafton", "Mason Glaves"]
    gem.add_development_dependency "rspec"
    gem.rubyforge_project = 'my-obfuscate'
  end

  Jeweler::RubyforgeTasks.new do |rubyforge|
    rubyforge.doc_task = "rdoc"
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "my_obfuscate #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
