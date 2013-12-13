# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "lims-exception-notifier-app/version"

Gem::Specification.new do |s|
  s.name        = "lims-exception-notifier-app"
  s.version     = Lims::ExceptionNotifierApp::VERSION
  s.authors     = ["Karoly Erdos"]
  s.email       = ["ke4@sanger.ac.uk"]
  s.homepage    = "http://sanger.ac.uk/"
  s.summary     = %q{This application sends an e-mail if an exception has been raised in the host application.}
  s.description = %q{Provides utility functions for the new LIMS}

  s.rubyforge_project = "lims-exception-notifier-app"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib", "config"]

  s.add_dependency("mustache", "~> 0.99.4")

  s.add_development_dependency('rake', '~> 0.9.2')
  s.add_development_dependency('rspec', '~> 2.8.0')
  s.add_development_dependency('yard', '>= 0.7.0')
  s.add_development_dependency('yard-rspec', '0.1')
  s.add_development_dependency('github-markup', '~> 0.7.1')
end

