Gem::Specification.new do |spec|
  spec.name          = "sequel-activerecord-adapter"
  spec.version       = "0.1.0"
  spec.authors       = ["Janko Marohnić"]
  spec.email         = ["janko.marohnic@gmail.com"]

  spec.summary       = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.description   = %q{Allows Sequel to use ActiveRecord connection for database interaction.}
  spec.homepage      = "https://github.com/janko/sequel-activerecord-adapter"
  spec.license       = "MIT"

  spec.required_ruby_version = Gem::Requirement.new(">= 2.2.0")

  spec.add_dependency "sequel", "~> 5.0"
  spec.add_dependency "activerecord", ">= 5.0", "< 7"

  spec.add_development_dependency "pg",      "~> 1.0"
  spec.add_development_dependency "mysql2",  "~> 0.5"
  spec.add_development_dependency "sqlite3", "~> 1.4"
  spec.add_development_dependency "minitest"

  spec.files         = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb", "*.gemspec"]
  spec.require_paths = ["lib"]
end
