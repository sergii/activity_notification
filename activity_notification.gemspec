$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "activity_notification/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name          = "activity_notification"
  s.version       = ActivityNotification::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Shota Yamazaki (simukappu)"]
  s.email         = ["shota.yamazaki.8@gmail.com"]
  s.homepage      = "https://github.com/simukappu/activity_notification"
  s.summary       = "Integrated user activity notifications for Rails"
  s.description   = "Integrated user activity notifications for Rails. Provides functions to configure multiple notification targets and make activity notifications with notifiable models, like adding comments, responding etc."
  s.license       = "MIT"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]
  s.required_ruby_version = '>= 2.1.0'

  s.add_dependency "rails", "~> 4.2.5"
  s.add_dependency 'activerecord', '>= 3.0'

  s.add_development_dependency 'sqlite3'
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency 'simplecov'
  s.add_development_dependency "devise"
end
