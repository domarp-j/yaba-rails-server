FactoryBot.define do
  factory :tag do
    name Faker::RickAndMorty.quote.gsub(/\s/, '')
  end
end
