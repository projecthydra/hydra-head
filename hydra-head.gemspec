# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hydra-head/version"

Gem::Specification.new do |s|
  s.name        = "hydra-head"
  s.version     = HydraHead::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matt Zumwalt, Bess Sadler, Julie Meloni, Naomi Dushay, Jessie Keck, John Scofield, Justin Coyne & many more.  See https://github.com/projecthydra/hydra-head/contributors"]
  s.email       = ["hydra-tech@googlegroups.com"]
  s.homepage    = "http://projecthydra.org"
  s.summary     = %q{Hydra-Head Rails Engine (requires Rails3) }
  s.description = %q{Hydra-Head is a Rails Engine containing the core code for a Hydra application. The full hydra stack includes: Blacklight, Fedora, Solr, active-fedora, solrizer, and om}

  s.add_dependency "rails", '~> 3.0.10'
  s.add_dependency "blacklight", '~>3.1.2'  
  s.add_dependency "devise"
  s.add_dependency "active-fedora", '>=3.3.0'
  s.add_dependency 'RedCloth', '=4.2.3'
  s.add_dependency 'solrizer-fedora', '>=1.2.2'
  s.add_dependency 'block_helpers'
  s.add_dependency 'sanitize'
  
  s.add_development_dependency 'sqlite3-ruby', '~>1.2.5'  #Locked here because centos 5.2 (Hudson) won't support a modern version

  s.add_development_dependency 'yard'
  s.add_development_dependency 'jettywrapper', ">=1.0.4"
  s.add_development_dependency 'ruby-debug'
  s.add_development_dependency 'ruby-debug-base'
  s.add_development_dependency 'rspec-rails', '>= 2.7.0'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'cucumber', '>=0.8.5'
  s.add_development_dependency 'cucumber-rails', '>=1.0.0'
  s.add_development_dependency 'gherkin'
  s.add_development_dependency 'factory_girl'
  s.add_development_dependency "rake"


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
