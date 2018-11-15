
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ace/version"

Gem::Specification.new do |spec|
  spec.name          = "agentless-catalog-executor"
  spec.version       = ACE::VERSION
  spec.authors       = ["David Schmitt"]
  spec.email         = ["david.schmitt@puppet.com"]

  spec.summary       = %q{ACE lets you run remote tasks and catalogs using puppet and bolt.}
  spec.homepage      = "https://github.com/puppetlabs/agentless-catalog-executor"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
