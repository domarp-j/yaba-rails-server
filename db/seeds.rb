unless Rails.env.production?
  puts 'Destroying existing users...'
  User.destroy_all
  puts 'Destroying all existing transactions...'
  TransactionItem.destroy_all
  puts 'Destroying all existing tags...'
  Tag.destroy_all

  puts 'Creating test user...'
  test_user = User.create(
    email: Rails.application.secrets[:seed_email] || 'test@example.com',
    username: Rails.application.secrets[:seed_username] || 'testuser',
    password: Rails.application.secrets[:seed_password] || 'test12345'
  )

  puts 'Done!'
end
