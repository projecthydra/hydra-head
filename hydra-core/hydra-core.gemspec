# -*- encoding: utf-8 -*-
version = File.read(File.expand_path("../../HYDRA_VERSION", __FILE__)).strip


Gem::Specification.new do |gem|
  gem.authors     = ["Matt Zumwalt, Bess Sadler, Julie Meloni, Naomi Dushay, Jessie Keck, John Scofield, Justin Coyne & many more.  See https://github.com/projecthydra/hydra-head/contributors"]
  gem.email       = ["hydra-tech@googlegroups.com"]
  gem.homepage    = "http://projecthydra.org"
  gem.summary     = %q{Hydra-Head Rails Engine (requires Rails3) }
  gem.description = %q{Hydra-Head is a Rails Engine containing the core code for a Hydra application. The full hydra stack includes: Blacklight, Fedora, Solr, active-fedora, solrizer, and om}

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "hydra-core"
  gem.require_paths = ["lib"]
  gem.version       = version
  gem.license       = "APACHE2"

  gem.required_ruby_version = '>= 2.1.0'


  gem.add_dependency "rails", '~> 4.1'
  gem.add_dependency 'block_helpers'
  gem.add_dependency 'hydra-access-controls', version
  gem.add_dependency 'jettywrapper', "~> 1.5"
  
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rspec-rails'
  gem.add_development_dependency 'factory_girl_rails'
end
