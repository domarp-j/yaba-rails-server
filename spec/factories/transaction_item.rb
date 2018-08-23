FactoryBot.define do
  factory :transaction_item do
    description Faker::NewGirl.quote
    value Faker::Number.decimal(2)
    date Time.now

    trait :income do
      description 'income'
      value 100
    end

    trait :purchase do
      description 'purchase'
      value(-100)
    end

    trait :large_income do
      description 'large income'
      value 1000
    end

    trait :large_purchase do
      description 'large purchase'
      value(-1000)
    end

    trait :repeated_purchase do
      description 'repeated purchase'
      value(-10)
    end

    trait :three_weeks_ago do
      date Time.now - 3.weeks
    end

    trait :two_weeks_ago do
      date Time.now - 2.weeks
    end

    trait :one_week_ago do
      date Time.now - 1.weeks
    end
  end
end
