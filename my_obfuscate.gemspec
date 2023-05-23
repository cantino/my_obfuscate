# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "my_obfuscate/version"

Gem::Specification.new do |s|
  s.name = %q{my_obfuscate}
  s.version = MyObfuscate::VERSION

  s.authors = ["Andrew Cantino", "Dave Willett", "Mike Grafton", "Mason Glaves", "Greg Bell", "Mavenlink"]
  s.description = %q{Standalone Ruby code for the selective rewriting of MySQL dumps in order to protect user privacy.}
  s.email = %q{andrew@mavenlink.com}
  s.homepage = %q{http://github.com/mavenlink/my_obfuscate}
  s.summary = %q{Standalone Ruby code for the selective rewriting of MySQL dumps in order to protect user privacy.}

  s.add_dependency "faker"
  s.add_dependency "walker_method"
  s.add_development_dependency "rspec"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
